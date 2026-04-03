from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path


DEFAULT_PERMISSIONS: dict[str, list[str]] = {
    "edge_status": ["admin", "operator", "viewer", "user"],
    "edge_history": ["admin", "operator", "viewer", "user"],
    "edge_dead_letter": ["admin", "operator"],
    "edge_control": ["admin", "operator"],
    "edge_network": ["admin"],
    "edge_drain": ["admin"],
    "edge_requeue_dead": ["admin"],
    "microclimate_optimize": ["admin", "operator", "viewer", "user"],
    "microclimate_execute": ["admin", "operator"],
    "incident_plan": ["admin", "operator", "viewer", "user"],
    "incident_auto_enqueue": ["admin", "operator"],
    "audit_view": ["admin"],
    "audit_export": ["admin"],
    "authz_policy_read": ["admin", "operator", "viewer"],
    "authz_policy_update": ["admin"],
}

DEFAULT_TEMPLATES: dict[str, dict[str, list[str]]] = {
    "strict": {
        "edge_status": ["admin", "operator"],
        "edge_history": ["admin", "operator"],
        "edge_dead_letter": ["admin"],
        "edge_control": ["admin", "operator"],
        "edge_network": ["admin"],
        "edge_drain": ["admin"],
        "edge_requeue_dead": ["admin"],
        "microclimate_optimize": ["admin", "operator"],
        "microclimate_execute": ["admin", "operator"],
        "incident_plan": ["admin", "operator"],
        "incident_auto_enqueue": ["admin", "operator"],
        "audit_view": ["admin"],
        "audit_export": ["admin"],
        "authz_policy_read": ["admin"],
        "authz_policy_update": ["admin"],
    },
    "standard": DEFAULT_PERMISSIONS,
    "demo": {
        "edge_status": ["admin", "operator", "viewer", "user"],
        "edge_history": ["admin", "operator", "viewer", "user"],
        "edge_dead_letter": ["admin", "operator", "viewer"],
        "edge_control": ["admin", "operator", "viewer"],
        "edge_network": ["admin", "operator"],
        "edge_drain": ["admin", "operator"],
        "edge_requeue_dead": ["admin", "operator"],
        "microclimate_optimize": ["admin", "operator", "viewer", "user"],
        "microclimate_execute": ["admin", "operator", "viewer"],
        "incident_plan": ["admin", "operator", "viewer", "user"],
        "incident_auto_enqueue": ["admin", "operator", "viewer"],
        "audit_view": ["admin", "operator"],
        "audit_export": ["admin", "operator"],
        "authz_policy_read": ["admin", "operator", "viewer"],
        "authz_policy_update": ["admin", "operator"],
    },
}


class AuthzPolicyService:
    def __init__(self) -> None:
        backend_dir = Path(__file__).resolve().parents[2]
        runtime_dir = backend_dir / "runtime"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        self._policy_file = runtime_dir / "ai_ops_role_policy.json"
        self._permissions: dict[str, list[str]] = {}
        self._updated_at: str = datetime.utcnow().isoformat()
        self._load()

    def _normalize(self, permissions: dict[str, list[str]]) -> dict[str, list[str]]:
        normalized: dict[str, list[str]] = {}
        for action, roles in permissions.items():
            if not isinstance(action, str):
                continue
            action_key = action.strip().lower()
            if not action_key:
                continue
            role_list = []
            if isinstance(roles, list):
                role_list = [str(role).strip().lower() for role in roles if str(role).strip()]
            # de-dup keep order
            dedup: list[str] = []
            for role in role_list:
                if role not in dedup:
                    dedup.append(role)
            normalized[action_key] = dedup
        return normalized

    def _load(self) -> None:
        if self._policy_file.exists():
            try:
                data = json.loads(self._policy_file.read_text(encoding="utf-8"))
                permissions = self._normalize(data.get("permissions", {}))
                if permissions:
                    self._permissions = permissions
                    self._updated_at = str(data.get("updated_at") or datetime.utcnow().isoformat())
                    return
            except Exception:
                pass
        self._permissions = self._normalize(DEFAULT_PERMISSIONS)
        self._updated_at = datetime.utcnow().isoformat()
        self._save()

    def _save(self) -> None:
        data = {
            "updated_at": self._updated_at,
            "permissions": self._permissions,
        }
        self._policy_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def allowed(self, role: str, action: str) -> bool:
        role_key = (role or "").strip().lower()
        action_key = (action or "").strip().lower()
        if not action_key:
            return False
        allow_roles = self._permissions.get(action_key, [])
        return role_key in allow_roles

    def read(self) -> dict[str, object]:
        return {
            "updated_at": self._updated_at,
            "permissions": self._permissions,
        }

    def update(self, permissions: dict[str, list[str]]) -> dict[str, object]:
        merged = self._normalize(DEFAULT_PERMISSIONS)
        merged.update(self._normalize(permissions))
        self._permissions = merged
        self._updated_at = datetime.utcnow().isoformat()
        self._save()
        return self.read()

    def templates(self) -> dict[str, object]:
        normalized_templates: dict[str, dict[str, list[str]]] = {}
        for name, permissions in DEFAULT_TEMPLATES.items():
            normalized_templates[name] = self._normalize(permissions)
        return {
            "current": self._permissions,
            "templates": normalized_templates,
        }

    def apply_template(self, template_name: str) -> dict[str, object]:
        key = (template_name or "").strip().lower()
        template = DEFAULT_TEMPLATES.get(key)
        if template is None:
            raise ValueError(f"unknown template: {template_name}")
        self._permissions = self._normalize(template)
        self._updated_at = datetime.utcnow().isoformat()
        self._save()
        return self.read()


authz_policy_service = AuthzPolicyService()
