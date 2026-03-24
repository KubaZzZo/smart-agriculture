# 智慧农业控制系统

基于 HarmonyOS ArkUI + FastAPI 的智慧农业物联网监控平台，实现温室环境实时监测、设备远程控制、智能预警与自动化联动。

## 项目结构

```
smart-agriculture/
├── frontend/          # HarmonyOS ArkUI 前端应用
│   ├── entry/src/main/ets/
│   │   ├── pages/     # 页面（登录、设备详情、灌溉、光照、作物、区域、报告、联动规则）
│   │   ├── views/     # 视图组件（仪表盘、监测、设备、预警、个人中心）
│   │   ├── common/    # 公共模块（API服务、常量定义）
│   │   └── model/     # 数据模型
│   └── AppScope/      # 应用配置
├── backend/           # Python FastAPI 后端服务
│   ├── app/
│   │   ├── routers/   # API路由（传感器、设备、预警、联动、定时任务、区域、作物、报告等）
│   │   ├── services/  # 业务服务（数据模拟、预警检测、自动化引擎）
│   │   ├── models.py  # ORM模型
│   │   ├── schemas.py # 请求/响应模型
│   │   └── main.py    # 应用入口
│   └── init.sql       # 数据库初始化脚本
```

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | HarmonyOS SDK 6.0、ArkUI (ArkTS)、ArkUI-X 跨平台 |
| 后端 | Python 3.13、FastAPI、SQLAlchemy 2.0、WebSocket |
| 数据库 | MySQL (PyMySQL) |
| 通信 | RESTful API + WebSocket 实时推送 |

## 功能模块

- **实时监测** — 温度、湿度、光照、CO₂、土壤湿度五项环境指标实时采集与展示
- **设备控制** — 水阀、水泵、LED补光灯、摄像头、通风风扇远程开关与参数调节
- **智能预警** — 自定义预警规则，超阈值自动触发告警并推送
- **自动化联动** — 条件触发式设备控制（如土壤湿度低于30%自动开启水泵）
- **智能灌溉** — 土壤湿度监测、灌溉量计算、用水统计
- **智能光照** — 光照强度监测、LED亮度调节、补光建议
- **作物管理** — 作物信息录入、生长阶段跟踪、目标环境参数设定
- **区域管理** — 温室/田地分区管理、设备关联
- **定时任务** — Cron表达式定时执行设备操作
- **数据报告** — 每日自动生成环境数据与运营摘要

## 快速开始

### 后端

```bash
cd backend

# 安装依赖
pip install -r requirements.txt

# 初始化数据库（MySQL）
mysql -u root -p < init.sql

# 配置环境变量（可选，默认值见 app/config.py）
cp .env.example .env

# 启动服务
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

启动后访问 http://localhost:8000/docs 查看 API 文档。

### 前端

使用 DevEco Studio 打开 `frontend/` 目录，连接 HarmonyOS 设备或模拟器运行。

需在 `frontend/entry/src/main/ets/common/Constants.ets` 中修改 `BASE_URL` 为后端实际地址。

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| DB_HOST | 数据库地址 | localhost |
| DB_PORT | 数据库端口 | 3306 |
| DB_USER | 数据库用户 | root |
| DB_PASSWORD | 数据库密码 | — |
| DB_NAME | 数据库名 | smart_agriculture |
| SECRET_KEY | JWT签名密钥 | — |
| SIMULATE_INTERVAL | 数据模拟间隔(秒) | 5 |
