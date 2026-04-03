# Smart Agriculture Control System

## Overview
Smart Agriculture is a HarmonyOS ArkUI + FastAPI project for greenhouse monitoring and device automation.

- Frontend: ArkUI (ArkTS)
- Backend: FastAPI + SQLAlchemy + MySQL
- Realtime: polling service in frontend (`RealtimeService.ets`) + backend APIs

## Project Structure
```text
smart-agriculture/
  frontend/
    entry/src/main/ets/
      common/      # constants, api service, realtime service
      pages/       # pages
      views/       # tab views
      model/       # data models
  backend/
    app/
      routers/
      services/
      main.py
```

## Backend Quick Start
```bash
cd backend
pip install -r requirements.txt
mysql -u root -p < init.sql
cp .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Frontend Environment Configuration
Frontend runtime keys are initialized in `EntryAbility.ets`:
- `APP_ENV` (`dev` | `staging` | `prod`)
- `API_BASE_URL` (optional override)
- `WS_BASE_URL` (optional override)

Default endpoint values are centralized in:
- `frontend/entry/src/main/ets/common/Constants.ets`
- class: `FrontendDeploy`

Update these values before release:
- `DEV_API_BASE_URL`, `DEV_WS_BASE_URL`
- `STAGING_API_BASE_URL`, `STAGING_WS_BASE_URL`
- `PROD_API_BASE_URL`, `PROD_WS_BASE_URL`

## Quality Checks
```bash
python scripts/check_encoding.py
python scripts/check_arkts_rules.py
```

## Notes
- `ApiService.get` uses `Map<string, string>` for query params to match strict ArkTS rules.
- Avoid using indexed signatures (`[key: string]`) in ArkTS interfaces.
