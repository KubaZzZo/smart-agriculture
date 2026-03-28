# ESP32 MicroPython 固件代码
# =====================================================
# 将以下代码保存为 main.py，烧录到 ESP32 即可
# 所需库：umqtt.simple（MicroPython 默认内置）
# 传感器：DHT22（温湿度）、BH1750（光照）
# =====================================================

import network
import ujson
import time
import machine
import dht
from umqtt.simple import MQTTClient

# ========== 配置区（按实际情况修改）==========
WIFI_SSID    = "您的WiFi名称"
WIFI_PWD     = "您的WiFi密码"
LOT_ID       = "GpCFElcvR"     # Easy IoT 工作间的 iot_id
LOT_PWD      = "GpjFE_cvgz"    # Easy IoT 工作间的 iot_pwd
TOPIC_TH     = b"kpdcE_cvg"    # 温湿度 Topic
TOPIC_LIGHT  = b"OrltElcDR"    # 光照 Topic
SEND_INTERVAL = 5               # 上报间隔（秒）
DHT_PIN      = 4                # DHT22 数据引脚
I2C_SCL      = 22               # BH1750 SCL 引脚
I2C_SDA      = 21               # BH1750 SDA 引脚
# ============================================


def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        print("正在连接 WiFi:", WIFI_SSID)
        wlan.connect(WIFI_SSID, WIFI_PWD)
        timeout = 15
        while not wlan.isconnected() and timeout > 0:
            time.sleep(1)
            timeout -= 1
    if wlan.isconnected():
        print("WiFi 已连接，IP:", wlan.ifconfig()[0])
    else:
        raise RuntimeError("WiFi 连接超时，请检查 SSID 和密码")


def read_bh1750(i2c) -> float:
    """读取 BH1750 光照强度（Lux）"""
    BH1750_ADDR = 0x23
    i2c.writeto(BH1750_ADDR, b'\x10')  # 连续高分辨率模式
    time.sleep_ms(180)
    raw = i2c.readfrom(BH1750_ADDR, 2)
    lux = (raw[0] << 8 | raw[1]) / 1.2
    return round(lux, 1)


def main():
    connect_wifi()

    # 初始化传感器
    dht_sensor = dht.DHT22(machine.Pin(DHT_PIN))
    i2c = machine.SoftI2C(scl=machine.Pin(I2C_SCL), sda=machine.Pin(I2C_SDA))

    # 连接 Easy IoT MQTT
    client = MQTTClient(
        client_id="esp32-farm",
        server="iot.dfrobot.com.cn",
        port=1883,
        user=LOT_ID,
        password=LOT_PWD,
        keepalive=60
    )
    client.connect()
    print("已连接 Easy IoT 平台")

    while True:
        try:
            # 读取 DHT22 温湿度
            dht_sensor.measure()
            temp = dht_sensor.temperature()
            hum  = dht_sensor.humidity()

            # 读取 BH1750 光照
            lux = read_bh1750(i2c)

            # 上报温湿度到 Topic_1
            payload_th = ujson.dumps({"temperature": temp, "humidity": hum})
            client.publish(TOPIC_TH, payload_th)

            # 上报光照到 Topic_2
            payload_light = ujson.dumps({"light": lux})
            client.publish(TOPIC_LIGHT, payload_light)

            print("上报成功 | 温度:{:.1f}°C 湿度:{:.1f}% 光照:{:.0f}Lux".format(temp, hum, lux))

        except OSError as e:
            print("传感器读取失败:", e)
        except Exception as e:
            print("上报失败，尝试重连:", e)
            try:
                client.connect()
            except Exception:
                pass

        time.sleep(SEND_INTERVAL)


main()
