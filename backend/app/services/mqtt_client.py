"""
Easy IoT MQTT 客户端服务
- 订阅来自 ESP32 的多路传感器数据 Topic
- 将接收到的数据写入全局缓存，供 simulator.py 优先读取
- 只有当 settings.MQTT_ENABLED=True 时才会启动
"""

import json
import time
import logging
import threading
from typing import Optional

import paho.mqtt.client as mqtt

from ..config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# 全局真实数据缓存（线程安全）
# ---------------------------------------------------------------------------
_lock = threading.Lock()

# 最新一次从 MQTT 收到的各项传感器值，None 表示从未收到
_real_cache: dict = {
    "temperature":    None,
    "humidity":       None,
    "light_intensity": None,
    "co2_level":      None,
    "soil_moisture":  None,
    "last_updated":   0.0,   # epoch 时间戳，用于计算 TTL
}


def get_real_data() -> Optional[dict]:
    """
    返回一份真实传感器数据快照，若缓存已过期或从未收到则返回 None。
    调用方（simulator.py）用此函数判断是否有可用的真实数据。
    """
    with _lock:
        if _real_cache["last_updated"] == 0.0:
            return None
        age = time.time() - _real_cache["last_updated"]
        if age > settings.MQTT_REAL_DATA_TTL:
            logger.debug("[MQTT] 真实数据已超过 TTL（%ds），回退到模拟数据", settings.MQTT_REAL_DATA_TTL)
            return None
        # 返回快照（排除元数据字段）
        return {
            "temperature":    _real_cache["temperature"],
            "humidity":       _real_cache["humidity"],
            "light_intensity": _real_cache["light_intensity"],
            "co2_level":      _real_cache["co2_level"],
            "soil_moisture":  _real_cache["soil_moisture"],
        }


def _update_cache(**kwargs) -> None:
    """线程安全地更新缓存中的若干字段。只更新非 None 的字段。"""
    with _lock:
        for key, value in kwargs.items():
            if key in _real_cache and value is not None:
                _real_cache[key] = value
        _real_cache["last_updated"] = time.time()


# ---------------------------------------------------------------------------
# MQTT 回调
# ---------------------------------------------------------------------------

def _on_connect(client: mqtt.Client, userdata, flags, rc: int) -> None:
    if rc == 0:
        logger.info("[MQTT] 已连接 Easy IoT 平台 (%s:%d)", settings.MQTT_HOST, settings.MQTT_PORT)
        # 订阅所有已配置的 Topic
        topics = [
            settings.MQTT_TOPIC_TEMP_HUM,
            settings.MQTT_TOPIC_LIGHT,
            settings.MQTT_TOPIC_CO2,
            settings.MQTT_TOPIC_SOIL,
        ]
        for topic in topics:
            if topic:
                client.subscribe(topic)
                logger.info("[MQTT] 已订阅 Topic: %s", topic)
    else:
        logger.warning("[MQTT] 连接失败，返回码: %d", rc)


def _on_disconnect(client: mqtt.Client, userdata, rc: int) -> None:
    if rc != 0:
        logger.warning("[MQTT] 连接意外断开 (rc=%d)，将自动重连…", rc)


def _parse_float(raw) -> Optional[float]:
    """安全地将任意值转换为 float，失败返回 None。"""
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def _on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage) -> None:
    """收到任意 Topic 的消息时触发。"""
    topic = msg.topic
    try:
        payload_str = msg.payload.decode("utf-8").strip()
        data = json.loads(payload_str)
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        logger.warning("[MQTT] Topic=%s 消息解析失败: %s", topic, e)
        return

    logger.debug("[MQTT] 收到消息 Topic=%s payload=%s", topic, payload_str)

    # 根据 Topic 解析对应字段
    if topic == settings.MQTT_TOPIC_TEMP_HUM:
        # ESP32 发送格式: {"temperature": 26.5, "humidity": 60.1}
        _update_cache(
            temperature=_parse_float(data.get("temperature")),
            humidity=_parse_float(data.get("humidity")),
        )
        logger.info("[MQTT] 温度=%.1f°C  湿度=%.1f%%",
                    data.get("temperature", 0), data.get("humidity", 0))

    elif topic == settings.MQTT_TOPIC_LIGHT:
        # ESP32 发送格式: {"light": 32000}
        _update_cache(light_intensity=_parse_float(data.get("light")))
        logger.info("[MQTT] 光照=%.0f Lux", data.get("light", 0))

    elif topic == settings.MQTT_TOPIC_CO2:
        # ESP32 发送格式: {"co2": 520}
        _update_cache(co2_level=_parse_float(data.get("co2")))
        logger.info("[MQTT] CO₂=%.0f ppm", data.get("co2", 0))

    elif topic == settings.MQTT_TOPIC_SOIL:
        # ESP32 发送格式: {"soil": 45.8}
        _update_cache(soil_moisture=_parse_float(data.get("soil")))
        logger.info("[MQTT] 土壤湿度=%.1f%%", data.get("soil", 0))


# ---------------------------------------------------------------------------
# 启动入口
# ---------------------------------------------------------------------------

def start_mqtt() -> None:
    """
    启动 MQTT 后台线程。若 MQTT_ENABLED=False 则静默跳过。
    必须在 FastAPI lifespan 启动阶段调用。
    """
    if not settings.MQTT_ENABLED:
        logger.info("[MQTT] MQTT_ENABLED=False，跳过 Easy IoT 接入（使用模拟数据）")
        return

    if not settings.MQTT_LOT_ID or not settings.MQTT_LOT_PWD:
        logger.warning("[MQTT] MQTT_LOT_ID 或 MQTT_LOT_PWD 未配置，跳过启动")
        return

    client = mqtt.Client(client_id=f"smart-farm-{int(time.time())}")
    client.username_pw_set(settings.MQTT_LOT_ID, settings.MQTT_LOT_PWD)
    client.on_connect = _on_connect
    client.on_disconnect = _on_disconnect
    client.on_message = _on_message

    try:
        client.connect(settings.MQTT_HOST, settings.MQTT_PORT, keepalive=60)
    except Exception as e:
        logger.error("[MQTT] 无法连接 Easy IoT 平台: %s（后端将使用模拟数据）", e)
        return

    # loop_start() 在独立守护线程中运行，不会阻塞 FastAPI 主进程
    client.loop_start()
    logger.info("[MQTT] 后台监听线程已启动")
