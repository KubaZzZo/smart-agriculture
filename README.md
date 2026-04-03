# 智慧农业控制系统

## 项目简介
本项目是一个基于 HarmonyOS ArkUI + FastAPI 的温室监测与设备自动化系统。

- 前端：ArkUI（ArkTS）
- 后端：FastAPI + SQLAlchemy + MySQL
- 实时能力：前端轮询（`RealtimeService.ets`）+ 后端 API/WebSocket
- Web 端页面：
  - 数据大屏：`/dashboard`
  - AI 运维台：`/ai-ops`

## 目录结构
```text
smart-agriculture/
  frontend/
    entry/src/main/ets/
      common/      # 常量、API 服务、实时服务
      pages/       # 页面
      views/       # 视图
      model/       # 数据模型
  backend/
    app/
      routers/     # 路由
      services/    # 业务服务
      main.py
    static/
      dashboard/   # Web 数据大屏
      ai-ops/      # AI 运维台
```

## 后端启动
```bash
cd backend
pip install -r requirements.txt
mysql -u root -p < init.sql
cp .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 前端环境配置
前端运行时变量在 `EntryAbility.ets` 中初始化：

- `APP_ENV`（`dev` | `staging` | `prod`）
- `API_BASE_URL`（可选覆盖）
- `WS_BASE_URL`（可选覆盖）

默认地址集中在：

- `frontend/entry/src/main/ets/common/Constants.ets`
- `FrontendDeploy` 类

发布前建议检查：

- `DEV_API_BASE_URL` / `DEV_WS_BASE_URL`
- `STAGING_API_BASE_URL` / `STAGING_WS_BASE_URL`
- `PROD_API_BASE_URL` / `PROD_WS_BASE_URL`

## 害虫识别模型说明
当前后端优先使用本地分类模型进行识别：

- 模型路径：`backend/models/classification/ip102/best_convnext_tiny_ip102.pt`
- 类别文件：`backend/models/classification/ip102/classes.txt`

若模型或依赖不可用，会自动回退到启发式识别逻辑（`heuristic_v2`），保证接口可用。

说明：`.pt` 大模型默认不提交到 GitHub（已在 `.gitignore` 排除），请在部署环境本地放置模型文件。

## 质量检查
```bash
python scripts/check_encoding.py
python scripts/check_arkts_rules.py
```

## 开发注意事项
- `ApiService.get` 查询参数使用 `Map<string, string>`，以满足 ArkTS 严格规则。
- 避免在 ArkTS 接口中使用索引签名（`[key: string]`）。
