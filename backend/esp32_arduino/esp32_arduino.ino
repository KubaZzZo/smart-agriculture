#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <U8g2lib.h>

// ========== 引脚配置 ==========
#define RELAY_PIN    26    // 继电器控制引脚（低电平触发）
#define SOIL_PIN     34    // 土壤湿度传感器模拟输出引脚（ADC）
#define I2C_SDA      21    // OLED SDA
#define I2C_SCL      22    // OLED SCL

// ========== WiFi / Easy IoT 配置（按实际填写）==========
const char* WIFI_SSID    = "Mate 40 Pro";
const char* WIFI_PWD     = "cjy20070327";
const char* MQTT_HOST    = "iot.dfrobot.com.cn";
const int   MQTT_PORT    = 1883;
const char* LOT_ID       = "GpCFElcvR";   // iot_id
const char* LOT_PWD      = "GpjFE_cvgz";  // iot_pwd
const char* TOPIC_SOIL   = "2dhAPlrDR";   // 土壤湿度 Topic（对应"3"卡片）

// ========== 土壤传感器校准值（根据实际测量调整）==========
const int SOIL_DRY_VALUE = 3200;   // 干燥时 ADC 读数
const int SOIL_WET_VALUE = 1200;   // 湿润时 ADC 读数

// ========== 上报间隔 ==========
const unsigned long SEND_INTERVAL = 2000; // 2秒上报一次

// ========== 全局对象 ==========
// 1.3寸 SH1106 硬件 I2C 构造函数
U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* reset=*/ U8X8_PIN_NONE);

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
unsigned long lastSendTime = 0;
bool heartBeat = false; 

// ---------- 土壤湿度读取 ----------
float readSoilMoisture() {
  int raw = analogRead(SOIL_PIN);
  float pct = map(raw, SOIL_DRY_VALUE, SOIL_WET_VALUE, 0, 100);
  pct = constrain(pct, 0.0f, 100.0f);
  return round(pct * 10) / 10.0f;
}

// ---------- 更新 U8g2 显示 ----------
void updateDisplay(float soilPct, bool relayOn) {
  u8g2.clearBuffer();

  // 1. 标题
  u8g2.setFont(u8g2_font_6x12_tr); 
  u8g2.drawStr(0, 10, "== SmartFarm ESP32 ==");

  // 2. 心跳灯
  heartBeat = !heartBeat;
  if (heartBeat) u8g2.drawDisc(122, 5, 2);

  // 3. 土壤湿度
  u8g2.setFont(u8g2_font_ncenB14_tr);
  u8g2.drawStr(0, 32, "Soil:");
  u8g2.setCursor(65, 32);
  u8g2.print(soilPct, 1);
  u8g2.drawStr(110, 32, "%");

  // 4. 继电器状态
  u8g2.setFont(u8g2_font_6x12_tr);
  u8g2.drawStr(0, 48, "Relay:");
  u8g2.setCursor(65, 48);
  u8g2.print(relayOn ? "[ ON  ] Run" : "[ OFF ] Idle");

  // 5. MQTT 状态
  u8g2.drawStr(0, 62, "MQTT:");
  u8g2.setCursor(65, 62);
  u8g2.print(mqttClient.connected() ? "Connected" : "Disconnected");

  u8g2.sendBuffer();
}

// ---------- MQTT 控制回调 ----------
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  
  StaticJsonDocument<128> doc;
  if (deserializeJson(doc, msg) == DeserializationError::Ok) {
    if (doc.containsKey("relay")) {
      int cmd = doc["relay"];
      if (cmd == 1) {
        digitalWrite(RELAY_PIN, LOW); // 吸合
        Serial.println("Control: RELAY ON");
      } else if (cmd == 0) {
        digitalWrite(RELAY_PIN, HIGH); // 断开
        Serial.println("Control: RELAY OFF");
      }
      // 收到指令后立即更新显示
      updateDisplay(readSoilMoisture(), digitalRead(RELAY_PIN) == LOW);
    }
  }
}

// ---------- 网络连接 ----------
void connectWifi() {
  Serial.print("WiFi Conn: ");
  WiFi.begin(WIFI_SSID, WIFI_PWD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nIP: " + WiFi.localIP().toString());
}

void connectMqtt() {
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(onMqttMessage);
  while (!mqttClient.connected()) {
    Serial.print("MQTT Conn...");
    String cid = "esp32-farm-" + String(random(0xffff), HEX);
    if (mqttClient.connect(cid.c_str(), LOT_ID, LOT_PWD)) {
      Serial.println("OK");
      mqttClient.subscribe(TOPIC_SOIL);
    } else {
      Serial.print("Fail rc="); Serial.println(mqttClient.state());
      delay(3000);
    }
  }
}

// ---------- 初始化 ----------
void setup() {
  Serial.begin(115200);
  
  // 继电器初始化
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);

  // I2C 和 OLED 初始化
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(400000);
  u8g2.begin();
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_6x13_tr);
  u8g2.drawStr(0, 30, "System Starting...");
  u8g2.sendBuffer();

  connectWifi();
  connectMqtt();
  Serial.println("System Ready!");
}

// ---------- 主循环 ----------
void loop() {
  if (!mqttClient.connected()) connectMqtt();
  mqttClient.loop();

  unsigned long now = millis();
  if (now - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = now;
    
    float soil = readSoilMoisture();
    bool relayOn = (digitalRead(RELAY_PIN) == LOW);

    // 1. 准备数据：纯数字字符串 (适配网页卡片) + JSON (适配 App)
    String rawVal = String(soil, 1);
    
    // 2. 发送数据并捕获结果
    bool success = mqttClient.publish(TOPIC_SOIL, rawVal.c_str());
    
    // 3. 串口输出详细日志
    Serial.printf("LOG | Soil:%.1f%%  Relay:%s  MQTT_Pub:%s\n", 
                  soil, relayOn ? "ON" : "OFF", success ? "SUCCESS" : "FAIL");
    
    if (!success) {
      Serial.print("ERR | MQTT Error state: "); Serial.println(mqttClient.state());
    }

    // 4. 更新屏幕显示
    updateDisplay(soil, relayOn);
  }
}
