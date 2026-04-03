from __future__ import annotations

from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import SensorData, User
from ..schemas import (
    AIOpsAuditResponse,
    AuthzApplyTemplateRequest,
    AuthzPolicyResponse,
    AuthzPolicyTemplatesResponse,
    AuthzPolicyUpdateRequest,
    EdgeControlRequest,
    EdgeDeadLetterResponse,
    EdgeHistoryResponse,
    EdgeNetworkRequest,
    EdgeStatusResponse,
    HuaweiWatchSyncRequest,
    HuaweiWatchSyncResponse,
    IncidentPlanRequest,
    IncidentPlanResponse,
    IncidentPlanStep,
    IntegrationRecordsResponse,
    MicroClimateAction,
    MobilePestTriggerRequest,
    MicroClimateOptimizeRequest,
    MicroClimateOptimizeResponse,
    OpenClawAutofixRequest,
    OpenClawAutofixResponse,
    OpenHarmonyHandoffRequest,
    OpenHarmonyHandoffResponse,
    PestDetectFromPathRequest,
    PestDetectResponse,
    PestFinalSummaryResponse,
    PestRealtimeListResponse,
    PestRealtimeItem,
    StrategyExecuteRequest,
    StrategyExecuteResponse,
    StrategyExecuteResult,
    WeatherForecastPoint,
    WeatherForecastResponse,
    WeatherPredictRequest,
    WeatherPredictResponse,
    XiaoYiCommandRequest,
    XiaoYiCommandResponse,
)
from ..services.ai_audit import ai_audit_service
from ..services.authz_policy import authz_policy_service
from ..services.edge_autonomy import edge_autonomy_service
from ..services.huawei_bridge import huawei_bridge_service
from ..services.microclimate_matrix import optimize_with_matrix
from ..services.openclaw_ops import auto_fix_incident
from ..services.pest_stream import pest_stream_service
from ..services.vision_ai import build_mock_leaf_image_bytes, detect_pest_risk_from_leaf
from ..services.weather_ai import build_control_suggestion, build_weather_forecast
from ..services.weather_provider import fetch_weather_forecast, geocode_city
from ..config import settings
from .auth import get_current_user

router = APIRouter()


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _audit(user: User, request: Request, action: str, result: str, detail: dict | None = None) -> None:
    ai_audit_service.log(
        actor=user.username,
        role=user.role,
        action=action,
        result=result,
        detail=detail or {},
        ip=_client_ip(request),
    )


def _require_action(user: User, request: Request, action: str) -> None:
    if authz_policy_service.allowed(user.role, action):
        return
    _audit(user, request, action, "denied", {"reason": "permission_denied", "role": user.role})
    raise HTTPException(status_code=403, detail="permission denied")


def _build_task_payload_from_action(action_text: str) -> tuple[str, dict]:
    text = action_text.strip().lower()
    if "fan" in text and "off" in text:
        return ("device_control", {"device_type": "fan", "status": 0})
    if "fan" in text or "vent" in text or "dehumid" in text:
        return ("device_control", {"device_type": "fan", "status": 1, "mode": "boost"})
    if "pump" in text and "off" in text:
        return ("device_control", {"device_type": "pump", "status": 0})
    if "pump" in text or "irrigation" in text:
        return ("device_control", {"device_type": "pump", "status": 1})
    if "spray" in text or "mist" in text:
        return ("device_control", {"device_type": "spray", "status": 1})
    return ("device_control", {"status": 1, "note": action_text})


def _parse_risk_levels_csv(value: str) -> set[str]:
    allowed = {"high", "medium", "low", "unknown"}
    items = {x.strip().lower() for x in value.split(",") if x.strip()}
    return {x for x in items if x in allowed}


@router.get("/weather-forecast", response_model=WeatherForecastResponse)
def get_weather_forecast(
    hours: int = Query(24, ge=1, le=72),
    city: str = Query("Beijing"),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    latest_sensor = db.query(SensorData).order_by(SensorData.id.desc()).first()
    if latest_sensor:
        current_temp = float(latest_sensor.temperature)
        current_humidity = float(latest_sensor.humidity)
    else:
        current_temp = 24.0
        current_humidity = 60.0

    lat_lon = geocode_city(city) or (39.9042, 116.4074)
    points_raw = fetch_weather_forecast(latitude=lat_lon[0], longitude=lat_lon[1], horizon_hours=hours)
    if not points_raw:
        points_raw = build_weather_forecast(
            current_temp=current_temp,
            current_humidity=current_humidity,
            current_weather="fallback",
            horizon_hours=hours,
        )

    suggestions = build_control_suggestion(points_raw)
    points = [WeatherForecastPoint(**row) for row in points_raw]
    return WeatherForecastResponse(horizon_hours=hours, points=points, suggestions=suggestions)


@router.post("/vision/pest-detect", response_model=PestDetectResponse)
async def pest_detect(
    file: UploadFile = File(...),
    source: str = Query("web"),
    camera_id: str = Query(""),
    zone_id: str = Query(""),
    _: User = Depends(get_current_user),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="image file required")
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty image")

    try:
        result = detect_pest_risk_from_leaf(data)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"image parse failed: {exc}") from exc

    pest_stream_service.record(source=source, result=result, camera_id=camera_id, zone_id=zone_id)
    return PestDetectResponse(**result)


@router.get("/vision/pest/latest", response_model=PestRealtimeItem)
def get_latest_pest_detection(
    source: str = Query("mobile"),
    _: User = Depends(get_current_user),
):
    latest = pest_stream_service.latest(source=source)
    if not latest:
        raise HTTPException(status_code=404, detail="no data")
    return PestRealtimeItem(**latest)


@router.post("/vision/pest-detect/mobile", response_model=PestDetectResponse)
def mobile_trigger_pest_detect(
    payload: MobilePestTriggerRequest,
    _: User = Depends(get_current_user),
):
    frame_bytes = build_mock_leaf_image_bytes(risk_hint=payload.risk_hint)
    result = detect_pest_risk_from_leaf(frame_bytes)
    pest_stream_service.record(
        source="mobile",
        result=result,
        camera_id=payload.camera_id,
        zone_id=payload.zone_id,
    )
    return PestDetectResponse(**result)


@router.post("/vision/pest-detect/from-path", response_model=PestDetectResponse)
def pest_detect_from_path(
    payload: PestDetectFromPathRequest,
    _: User = Depends(get_current_user),
):
    image_url = payload.image_url.strip()
    image_bytes: bytes | None = None
    if image_url.startswith("/static/camera/"):
        backend_dir = Path(__file__).resolve().parents[2]
        static_dir = backend_dir / "static"
        rel_path = image_url.removeprefix("/static/")
        file_path = (static_dir / rel_path).resolve()
        try:
            file_path.relative_to(static_dir.resolve())
        except ValueError:
            file_path = static_dir / "camera" / "fallback.invalid"
        if file_path.exists() and file_path.is_file():
            if file_path.suffix.lower() in {".png", ".jpg", ".jpeg", ".bmp", ".webp"}:
                raw = file_path.read_bytes()
                if raw:
                    image_bytes = raw

    if image_bytes is None:
        image_bytes = build_mock_leaf_image_bytes(risk_hint=payload.risk_hint_fallback)

    result = detect_pest_risk_from_leaf(image_bytes)
    pest_stream_service.record(
        source=payload.source,
        result=result,
        camera_id=payload.camera_id,
        zone_id=payload.zone_id,
    )
    return PestDetectResponse(**result)


@router.get("/vision/pest/final-summary", response_model=PestFinalSummaryResponse)
def get_pest_final_summary(
    window_minutes: int = Query(60, ge=1, le=24 * 60),
    source: str = Query("all"),
    risk_levels: str = Query(""),
    _: User = Depends(get_current_user),
):
    source_value = "" if source == "all" else source
    risk_level_set = _parse_risk_levels_csv(risk_levels)
    data = pest_stream_service.final_summary(
        window_minutes=window_minutes,
        source=source_value,
        risk_levels=risk_level_set,
    )
    return PestFinalSummaryResponse(**data)


@router.get("/vision/pest/recent", response_model=PestRealtimeListResponse)
def get_recent_pest_detections(
    limit: int = Query(20, ge=1, le=200),
    source: str = Query("mobile"),
    since_minutes: int = Query(0, ge=0, le=24 * 60),
    risk_levels: str = Query(""),
    _: User = Depends(get_current_user),
):
    source_value = "" if source == "all" else source
    risk_level_set = _parse_risk_levels_csv(risk_levels)
    items = pest_stream_service.query(
        limit=limit,
        source=source_value,
        since_minutes=since_minutes,
        risk_levels=risk_level_set,
    )
    return PestRealtimeListResponse(
        total=len(items),
        source=source_value or "all",
        since_minutes=since_minutes,
        risk_levels=sorted(list(risk_level_set)),
        items=[PestRealtimeItem(**x) for x in items],
    )


@router.get("/edge/status", response_model=EdgeStatusResponse)
def edge_status(http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "edge_status")
    return EdgeStatusResponse(**edge_autonomy_service.status())


@router.get("/edge/history", response_model=EdgeHistoryResponse)
def edge_history(
    http_request: Request,
    limit: int = Query(80, ge=1, le=300),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "edge_history")
    return EdgeHistoryResponse(**edge_autonomy_service.history(limit=limit))


@router.get("/edge/dead-letter", response_model=EdgeDeadLetterResponse)
def edge_dead_letter(
    http_request: Request,
    limit: int = Query(80, ge=1, le=300),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "edge_dead_letter")
    return EdgeDeadLetterResponse(**edge_autonomy_service.dead_letter(limit=limit))


@router.post("/edge/network")
def edge_network(request: EdgeNetworkRequest, http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "edge_network")
    result = edge_autonomy_service.set_network(request.online)
    _audit(current_user, http_request, "edge_network", "ok", {"online": request.online})
    return result


@router.post("/edge/control")
def edge_control(request: EdgeControlRequest, http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "edge_control")
    result = edge_autonomy_service.enqueue_or_execute(
        task_id=request.task_id,
        action=request.action,
        payload=request.payload,
    )
    _audit(
        current_user,
        http_request,
        "edge_control",
        "ok",
        {"task_id": request.task_id, "action": request.action, "mode": result.get("mode", "")},
    )
    return result


@router.post("/edge/drain")
def edge_drain(http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "edge_drain")
    result = edge_autonomy_service.drain_now()
    _audit(current_user, http_request, "edge_drain", "ok", {"flushed_count": result.get("flushed_count", 0)})
    return result


@router.post("/edge/dead-letter/{task_id}/requeue")
def edge_requeue_dead(task_id: str, http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "edge_requeue_dead")
    result = edge_autonomy_service.requeue_dead_task(task_id)
    _audit(current_user, http_request, "edge_requeue_dead", "ok" if result.get("ok") else "failed", {"task_id": task_id})
    return result


@router.post("/microclimate/optimize", response_model=MicroClimateOptimizeResponse)
def optimize_microclimate(
    payload: MicroClimateOptimizeRequest,
    _: User = Depends(get_current_user),
):
    matrix = optimize_with_matrix([zone.model_dump() for zone in payload.zones])
    actions = [MicroClimateAction(**item) for item in matrix["actions"]]
    return MicroClimateOptimizeResponse(generated_at=matrix["generated_at"], actions=actions)


@router.post("/microclimate/execute", response_model=StrategyExecuteResponse)
def execute_microclimate_strategy(
    payload: StrategyExecuteRequest,
    http_request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "microclimate_execute")
    results: list[StrategyExecuteResult] = []
    for zone in payload.actions:
        submitted: list[dict] = []
        for index, action_text in enumerate(zone.actions):
            task_action, task_payload = _build_task_payload_from_action(action_text)
            task_payload["zone_id"] = zone.zone_id
            task_payload["zone_name"] = zone.zone_name
            result = edge_autonomy_service.enqueue_or_execute(
                task_id=f"zone-{zone.zone_id}-{index + 1}-{int(datetime.utcnow().timestamp())}",
                action=task_action,
                payload=task_payload,
            )
            submitted.append(result)
        results.append(StrategyExecuteResult(zone_id=zone.zone_id, zone_name=zone.zone_name, submitted=submitted))

    response = StrategyExecuteResponse(
        generated_at=datetime.utcnow().isoformat(),
        source=payload.source,
        results=results,
    )
    _audit(current_user, http_request, "microclimate_execute", "ok", {"zone_count": len(payload.actions)})
    return response


@router.post("/incident/plan", response_model=IncidentPlanResponse)
def build_incident_plan(
    payload: IncidentPlanRequest,
    http_request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "incident_plan")
    risk = payload.risk_level.lower()
    if payload.scenario == "pest_detect":
        steps = [
            IncidentPlanStep(order=1, title="Isolate zone", detail=f"Temporarily isolate {payload.zone_name}"),
            IncidentPlanStep(order=2, title="Image re-check", detail="Capture additional samples for validation"),
            IncidentPlanStep(order=3, title="Environment suppression", detail="Lower humidity and improve ventilation"),
            IncidentPlanStep(order=4, title="Track for 24h", detail="Observe risk trend after actions"),
        ]
    elif payload.scenario == "weather_risk":
        steps = [
            IncidentPlanStep(order=1, title="Pre-adjust strategy", detail="Apply control changes 2-6 hours early"),
            IncidentPlanStep(order=2, title="Irrigation tuning", detail="Adjust pump threshold and duration"),
            IncidentPlanStep(order=3, title="Device readiness", detail="Verify fan/light/pump execution status"),
            IncidentPlanStep(order=4, title="Offline fallback", detail="Switch to edge queue during network outage"),
        ]
    else:
        steps = [
            IncidentPlanStep(order=1, title="Confirm alert", detail="Confirm source and impact radius"),
            IncidentPlanStep(order=2, title="Fast response", detail="Run first-stage mitigation actions"),
            IncidentPlanStep(order=3, title="Retrospective", detail="Record outcome and update thresholds"),
        ]

    if risk == "high":
        steps.append(IncidentPlanStep(order=len(steps) + 1, title="Escalate", detail="Notify on-call manager"))

    enqueued_tasks: list[dict] = []
    if payload.auto_enqueue:
        _require_action(current_user, http_request, "incident_auto_enqueue")
        for step in steps[:2]:
            enqueued_tasks.append(
                edge_autonomy_service.enqueue_or_execute(
                    task_id=f"incident-{payload.scenario}-{step.order}-{int(datetime.utcnow().timestamp())}",
                    action="incident_step",
                    payload={
                        "scenario": payload.scenario,
                        "risk_level": payload.risk_level,
                        "step_order": step.order,
                        "step_title": step.title,
                        "zone_id": payload.zone_id,
                        "zone_name": payload.zone_name,
                        "pest_type": payload.pest_type,
                    },
                )
            )

    response = IncidentPlanResponse(
        generated_at=datetime.utcnow().isoformat(),
        scenario=payload.scenario,
        risk_level=payload.risk_level,
        steps=steps,
        enqueued_tasks=enqueued_tasks,
    )
    _audit(
        current_user,
        http_request,
        "incident_plan",
        "ok",
        {"scenario": payload.scenario, "risk": payload.risk_level, "auto_enqueue": payload.auto_enqueue},
    )
    return response


@router.get("/audit", response_model=AIOpsAuditResponse)
def get_ai_ops_audit(
    http_request: Request,
    limit: int = Query(200, ge=1, le=2000),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "audit_view")
    rows = ai_audit_service.list(limit=limit)
    return AIOpsAuditResponse(total=len(rows), items=rows)


@router.get("/audit/export.csv")
def export_ai_ops_audit_csv(
    http_request: Request,
    limit: int = Query(1000, ge=1, le=5000),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "audit_export")
    content = ai_audit_service.export_csv(limit=limit)
    return Response(
        content=content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="ai_ops_audit.csv"'},
    )


@router.get("/authz/policy", response_model=AuthzPolicyResponse)
def get_authz_policy(http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "authz_policy_read")
    return AuthzPolicyResponse(**authz_policy_service.read())


@router.post("/authz/policy", response_model=AuthzPolicyResponse)
def update_authz_policy(
    payload: AuthzPolicyUpdateRequest,
    http_request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "authz_policy_update")
    data = authz_policy_service.update(payload.permissions)
    _audit(current_user, http_request, "authz_policy_update", "ok", {"keys": list(payload.permissions.keys())})
    return AuthzPolicyResponse(**data)


@router.get("/authz/templates", response_model=AuthzPolicyTemplatesResponse)
def get_authz_templates(http_request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, http_request, "authz_policy_read")
    return AuthzPolicyTemplatesResponse(**authz_policy_service.templates())


@router.post("/authz/policy/apply-template", response_model=AuthzPolicyResponse)
def apply_authz_template(
    payload: AuthzApplyTemplateRequest,
    http_request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, http_request, "authz_policy_update")
    try:
        data = authz_policy_service.apply_template(payload.template_name)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    _audit(current_user, http_request, "authz_policy_apply_template", "ok", {"template_name": payload.template_name})
    return AuthzPolicyResponse(**data)


@router.post("/integration/huawei/watch/sync", response_model=HuaweiWatchSyncResponse)
def sync_huawei_watch(payload: HuaweiWatchSyncRequest, request: Request):
    configured = [item.strip() for item in settings.HUAWEI_WATCH_TOKENS.split(",") if item.strip()]
    if not configured:
        raise HTTPException(status_code=503, detail="watch_token_not_configured")
    token = request.headers.get("x-watch-token", "").strip()
    if not huawei_bridge_service.valid_watch_token(token):
        raise HTTPException(status_code=403, detail="invalid_watch_token")
    data = huawei_bridge_service.ingest_watch_sample(payload.model_dump())
    return HuaweiWatchSyncResponse(**data)


@router.post("/integration/huawei/xiaoyi/command", response_model=XiaoYiCommandResponse)
def run_xiaoyi_command(
    payload: XiaoYiCommandRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, request, "edge_control")
    if not settings.XIAOYI_SHARED_SECRET.strip():
        raise HTTPException(status_code=503, detail="xiaoyi_secret_not_configured")
    secret = request.headers.get("x-xiaoyi-secret", "").strip()
    if not huawei_bridge_service.valid_xiaoyi_secret(secret):
        raise HTTPException(status_code=403, detail="invalid_xiaoyi_secret")
    accepted = huawei_bridge_service.ingest_xiaoyi_command(payload.model_dump())
    task_action, task_payload = _build_task_payload_from_action(payload.text or payload.intent)
    dispatched = edge_autonomy_service.enqueue_or_execute(
        task_id=f"xiaoyi-{payload.intent}-{int(datetime.utcnow().timestamp())}",
        action=task_action,
        payload=task_payload,
    )
    _audit(current_user, request, "xiaoyi_command", "ok", {"intent": payload.intent, "action": task_action})
    return XiaoYiCommandResponse(accepted=accepted["accepted"], command=accepted["command"], dispatched=[dispatched])


@router.post("/integration/openharmony/handoff", response_model=OpenHarmonyHandoffResponse)
def openharmony_handoff(
    payload: OpenHarmonyHandoffRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, request, "edge_control")
    data = huawei_bridge_service.record_handoff(payload.model_dump())
    _audit(
        current_user,
        request,
        "openharmony_handoff",
        "ok",
        {"source": payload.source_device, "target": payload.target_device, "method": payload.method},
    )
    return OpenHarmonyHandoffResponse(**data)


@router.get("/integration/huawei/watch/recent", response_model=IntegrationRecordsResponse)
def get_recent_huawei_watch_samples(
    request: Request,
    limit: int = Query(20, ge=1, le=200),
    zone_id: str = Query(""),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, request, "edge_status")
    rows = huawei_bridge_service.recent_watch_samples(limit=limit, zone_id=zone_id)
    return IntegrationRecordsResponse(total=len(rows), items=rows)


@router.get("/integration/huawei/xiaoyi/recent", response_model=IntegrationRecordsResponse)
def get_recent_xiaoyi_commands(
    request: Request,
    limit: int = Query(20, ge=1, le=200),
    intent: str = Query(""),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, request, "edge_status")
    rows = huawei_bridge_service.recent_xiaoyi_commands(limit=limit, intent=intent)
    return IntegrationRecordsResponse(total=len(rows), items=rows)


@router.get("/integration/openharmony/handoff/recent", response_model=IntegrationRecordsResponse)
def get_recent_openharmony_handoffs(
    request: Request,
    limit: int = Query(20, ge=1, le=200),
    active_only: bool = Query(False),
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, request, "edge_status")
    rows = huawei_bridge_service.recent_handoffs(limit=limit, active_only=active_only)
    return IntegrationRecordsResponse(total=len(rows), items=rows)


@router.post("/openclaw/autofix", response_model=OpenClawAutofixResponse)
def openclaw_autofix(
    payload: OpenClawAutofixRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    _require_action(current_user, request, "edge_control")
    data = auto_fix_incident(incident_type=payload.incident_type, context=payload.context, dry_run=payload.dry_run)
    _audit(
        current_user,
        request,
        "openclaw_autofix",
        "ok",
        {"incident_type": payload.incident_type, "dry_run": payload.dry_run, "submitted": len(data.get("submitted", []))},
    )
    return OpenClawAutofixResponse(**data)


@router.post("/weather/predictive", response_model=WeatherPredictResponse)
def ai_predictive_weather(
    payload: WeatherPredictRequest,
    _: User = Depends(get_current_user),
):
    if payload.latitude is None or payload.longitude is None:
        lat, lon = geocode_city(payload.city) or (39.9042, 116.4074)
    else:
        lat, lon = payload.latitude, payload.longitude
    horizon = max(1, min(payload.horizon_hours, 72))
    rows = fetch_weather_forecast(latitude=float(lat), longitude=float(lon), horizon_hours=horizon)
    suggestions = build_control_suggestion(rows)
    points = [WeatherForecastPoint(**row) for row in rows]
    return WeatherPredictResponse(
        city=payload.city,
        latitude=float(lat),
        longitude=float(lon),
        horizon_hours=horizon,
        points=points,
        suggestions=suggestions,
    )


@router.get("/integration/status")
def integration_status(request: Request, current_user: User = Depends(get_current_user)):
    _require_action(current_user, request, "edge_status")
    return {"huawei_openharmony": huawei_bridge_service.status(), "edge": edge_autonomy_service.status()}
