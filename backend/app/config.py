from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = "1025"
    DB_NAME: str = "smart_agriculture"
    SECRET_KEY: str = "smart_agriculture_secret_2024"
    SIMULATE_INTERVAL: int = 5  # seconds

    # Easy IoT MQTT 配置（对应 iot.dfrobot.com.cn 平台）
    MQTT_ENABLED: bool = False          # 设为 True 才开启真实设备接入
    MQTT_HOST: str = "iot.dfrobot.com.cn"
    MQTT_PORT: int = 1883
    MQTT_LOT_ID: str = ""               # 对应平台的 iot_id
    MQTT_LOT_PWD: str = ""              # 对应平台的 iot_pwd
    # 各传感器对应的 Topic（与 Easy IoT 工作间保持一致）
    MQTT_TOPIC_TEMP_HUM: str = ""       # 温湿度 Topic
    MQTT_TOPIC_LIGHT: str = ""          # 光照强度 Topic
    MQTT_TOPIC_CO2: str = ""            # CO₂ Topic
    MQTT_TOPIC_SOIL: str = ""           # 土壤湿度 Topic
    # 真实数据有效期（秒）：超过此时间没有收到真实数据则回退到模拟数据
    MQTT_REAL_DATA_TTL: int = 30

    class Config:
        env_file = ".env"


settings = Settings()
