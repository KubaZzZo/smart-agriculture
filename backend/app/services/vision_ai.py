from __future__ import annotations

from io import BytesIO
from pathlib import Path
import random
from typing import Any

from PIL import Image, ImageDraw

MODEL_DIR = Path(__file__).resolve().parents[2] / "models" / "classification" / "ip102"
MODEL_PATH = MODEL_DIR / "best_convnext_tiny_ip102.pt"
CLASSES_PATH = MODEL_DIR / "classes.txt"

_MODEL_BUNDLE: dict[str, Any] | None = None
_MODEL_LOAD_ERROR: str = ""


def _clamp(value: float, low: float, high: float) -> float:
    if value < low:
        return low
    if value > high:
        return high
    return value


def _safe_div(a: float, b: float) -> float:
    if b == 0:
        return 0.0
    return a / b


def _extract_features(img: Image.Image) -> dict[str, float]:
    resized = img.resize((256, 256))
    pixels = list(resized.getdata())
    total = len(pixels)
    if total == 0:
        return {}

    green_dom = 0
    brown_red = 0
    yellow_ratio = 0
    dark_spot = 0
    brightness_sum = 0.0

    # Texture proxy by local luminance deltas on sampled grid.
    texture_sum = 0.0
    texture_count = 0

    width, height = resized.size
    luminance_map: list[float] = []
    for r, g, b in pixels:
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        luminance_map.append(lum)
        brightness_sum += lum

        if g > r * 1.06 and g > b * 1.06:
            green_dom += 1
        if r > 95 and g < 120 and b < 110 and r > g * 1.08:
            brown_red += 1
        if r > 115 and g > 105 and b < 105 and abs(r - g) < 45:
            yellow_ratio += 1
        if r < 72 and g < 72 and b < 72:
            dark_spot += 1

    stride = 3
    for y in range(0, height - stride, stride):
        base = y * width
        next_row = (y + stride) * width
        for x in range(0, width - stride, stride):
            idx = base + x
            right = idx + stride
            down = next_row + x
            texture_sum += abs(luminance_map[idx] - luminance_map[right])
            texture_sum += abs(luminance_map[idx] - luminance_map[down])
            texture_count += 2

    brightness = _safe_div(brightness_sum, total)
    texture = _safe_div(texture_sum, texture_count) / 255.0

    return {
        "green_ratio": _safe_div(green_dom, total),
        "brown_ratio": _safe_div(brown_red, total),
        "yellow_ratio": _safe_div(yellow_ratio, total),
        "dark_spot_ratio": _safe_div(dark_spot, total),
        "brightness": _clamp(brightness / 255.0, 0.0, 1.0),
        "texture": _clamp(texture, 0.0, 1.0),
    }


def _quality_score(width: int, height: int, brightness: float, texture: float) -> float:
    area = width * height
    size_score = _clamp(_safe_div(area, 640 * 640), 0.25, 1.0)
    bright_score = 1.0 - min(abs(brightness - 0.56), 0.56) / 0.56
    texture_score = _clamp(texture / 0.18, 0.25, 1.0)
    return _clamp(0.45 * size_score + 0.35 * bright_score + 0.20 * texture_score, 0.0, 1.0)


def _infer_risk(features: dict[str, float], quality: float) -> tuple[str, str, float]:
    green_ratio = features.get("green_ratio", 0.0)
    brown_ratio = features.get("brown_ratio", 0.0)
    yellow_ratio = features.get("yellow_ratio", 0.0)
    dark_spot_ratio = features.get("dark_spot_ratio", 0.0)
    texture = features.get("texture", 0.0)

    score = 0.0
    score += brown_ratio * 2.5
    score += yellow_ratio * 1.9
    score += dark_spot_ratio * 1.4
    score += max(0.0, 0.42 - green_ratio) * 1.8
    score += min(texture, 0.35) * 0.8
    score = _clamp(score, 0.0, 1.0)

    if brown_ratio > 0.13 and dark_spot_ratio > 0.06:
        pest_type = "leaf_spot_or_fungal_risk"
    elif yellow_ratio > 0.12 and green_ratio < 0.38:
        pest_type = "aphid_or_stress_risk"
    elif dark_spot_ratio > 0.09 and texture > 0.12:
        pest_type = "mite_or_thrips_risk"
    elif score < 0.34:
        pest_type = "none"
    else:
        pest_type = "possible_leaf_stress"

    if score >= 0.66:
        risk = "high"
    elif score >= 0.38:
        risk = "medium"
    else:
        risk = "low"

    separation = min(abs(score - 0.66), abs(score - 0.38))
    confidence = 0.50 + 0.35 * quality + 0.25 * _clamp(separation / 0.38, 0.0, 1.0)
    confidence = _clamp(confidence, 0.35, 0.97)
    return risk, pest_type, confidence


def _build_suggestions(risk_level: str, pest_type: str, quality: float) -> list[str]:
    suggestions: list[str] = []
    if risk_level == "high":
        suggestions.append("建议立即复拍同一叶片正反面，并安排人工复核。")
        suggestions.append("建议对当前区域启动隔离巡检，缩短巡检间隔至2小时。")
    elif risk_level == "medium":
        suggestions.append("建议在6-12小时内复拍并对比风险变化。")
        suggestions.append("建议适度增强通风并检查湿度是否持续偏高。")
    else:
        suggestions.append("当前风险较低，建议按日常频率持续监测。")

    if pest_type != "none":
        suggestions.append("建议同步抽检邻近植株叶片，确认是否存在扩散趋势。")

    if quality < 0.55:
        suggestions.append("图片质量一般，建议在自然光下近距离重新拍摄以提升准确度。")

    return suggestions


def _load_classes(path: Path) -> list[str]:
    names = [f"class_{i}" for i in range(102)]
    if not path.exists():
        return names
    try:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            row = line.strip()
            if not row:
                continue
            parts = row.split()
            if len(parts) < 2:
                continue
            idx = int(parts[0]) - 1
            if 0 <= idx < 102:
                names[idx] = " ".join(parts[1:]).strip() or names[idx]
    except Exception:
        return names
    return names


def _load_model_bundle() -> dict[str, Any] | None:
    global _MODEL_BUNDLE, _MODEL_LOAD_ERROR
    if _MODEL_BUNDLE is not None:
        return _MODEL_BUNDLE
    if _MODEL_LOAD_ERROR:
        return None

    if not MODEL_PATH.exists():
        _MODEL_LOAD_ERROR = f"model_not_found:{MODEL_PATH}"
        return None

    try:
        import torch
        from torch import nn
        from torchvision import models, transforms
    except Exception as exc:
        _MODEL_LOAD_ERROR = f"torch_import_error:{exc}"
        return None

    try:
        model = models.convnext_tiny(weights=None)
        in_features = int(model.classifier[2].in_features)
        model.classifier[2] = nn.Linear(in_features, 102)
        ckpt = torch.load(str(MODEL_PATH), map_location="cpu")
        state = ckpt["model"] if isinstance(ckpt, dict) and "model" in ckpt else ckpt
        model.load_state_dict(state, strict=True)
        model.eval()
        tf = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ]
        )
        _MODEL_BUNDLE = {
            "torch": torch,
            "model": model,
            "transform": tf,
            "class_names": _load_classes(CLASSES_PATH),
        }
        return _MODEL_BUNDLE
    except Exception as exc:
        _MODEL_LOAD_ERROR = f"model_load_error:{exc}"
        return None


def _predict_with_convnext(img: Image.Image) -> dict[str, Any] | None:
    bundle = _load_model_bundle()
    if bundle is None:
        return None

    torch = bundle["torch"]
    model = bundle["model"]
    tf = bundle["transform"]
    class_names: list[str] = bundle["class_names"]

    x = tf(img).unsqueeze(0)
    x_flip = torch.flip(x, dims=[3])
    with torch.no_grad():
        logits = (model(x) + model(x_flip)) / 2.0
        probs = torch.softmax(logits, dim=1).squeeze(0)

    top_vals, top_idx = torch.topk(probs, k=3)
    ids = [int(i) for i in top_idx.tolist()]
    vals = [float(v) for v in top_vals.tolist()]
    labels = [class_names[idx] if idx < len(class_names) else f"class_{idx}" for idx in ids]

    return {
        "top1_id": ids[0],
        "top1_label": labels[0],
        "top1_prob": vals[0],
        "top3": [{"id": ids[i], "label": labels[i], "prob": vals[i]} for i in range(3)],
    }


def _risk_from_model(top1_prob: float, quality: float) -> str:
    score = 0.72 * _clamp(top1_prob, 0.0, 1.0) + 0.28 * _clamp(quality, 0.0, 1.0)
    if score >= 0.72:
        return "high"
    if score >= 0.48:
        return "medium"
    return "low"


def _detect_with_heuristic(img: Image.Image) -> dict[str, Any]:
    width, height = img.size
    features = _extract_features(img)
    if not features:
        return {
            "risk_level": "unknown",
            "confidence": 0.0,
            "pest_type": "unknown",
            "reason": "empty_image",
            "engine": "heuristic_v2",
            "quality_score": 0.0,
            "metrics": {},
            "suggestions": ["未解析到有效像素，请重新上传图片。"],
        }

    quality = _quality_score(
        width=width,
        height=height,
        brightness=features.get("brightness", 0.0),
        texture=features.get("texture", 0.0),
    )
    risk_level, pest_type, confidence = _infer_risk(features, quality)
    suggestions = _build_suggestions(risk_level, pest_type, quality)
    reason = (
        f"green={features.get('green_ratio', 0.0):.3f}, "
        f"brown={features.get('brown_ratio', 0.0):.3f}, "
        f"yellow={features.get('yellow_ratio', 0.0):.3f}, "
        f"dark={features.get('dark_spot_ratio', 0.0):.3f}, "
        f"texture={features.get('texture', 0.0):.3f}, "
        f"quality={quality:.3f}"
    )
    return {
        "risk_level": risk_level,
        "confidence": round(confidence, 2),
        "pest_type": pest_type,
        "reason": reason,
        "engine": "heuristic_v2",
        "quality_score": round(quality, 3),
        "metrics": {k: round(v, 4) for k, v in features.items()},
        "suggestions": suggestions,
    }


def detect_pest_risk_from_leaf(image_bytes: bytes) -> dict[str, Any]:
    img = Image.open(BytesIO(image_bytes)).convert("RGB")
    width, height = img.size
    if width < 120 or height < 120:
        return {
            "risk_level": "unknown",
            "confidence": 0.35,
            "pest_type": "unknown",
            "reason": "image_too_small",
            "engine": "heuristic_v2",
            "quality_score": 0.25,
            "metrics": {},
            "suggestions": ["图片分辨率过低，请重新拍摄清晰叶片特写。"],
        }

    features = _extract_features(img)
    quality = _quality_score(
        width=width,
        height=height,
        brightness=features.get("brightness", 0.0),
        texture=features.get("texture", 0.0),
    )

    prediction = _predict_with_convnext(img)
    if prediction is None:
        return _detect_with_heuristic(img)

    top1_prob = float(prediction["top1_prob"])
    top3 = prediction["top3"]
    risk_level = _risk_from_model(top1_prob, quality)
    confidence = _clamp(0.68 * top1_prob + 0.32 * quality, 0.30, 0.99)
    pest_type = str(prediction["top1_label"])
    suggestions = _build_suggestions(risk_level, pest_type, quality)

    reason = (
        f"model=convnext_tiny_ip102, "
        f"top1={top3[0]['label']}:{top3[0]['prob']:.3f}, "
        f"top2={top3[1]['label']}:{top3[1]['prob']:.3f}, "
        f"top3={top3[2]['label']}:{top3[2]['prob']:.3f}, "
        f"quality={quality:.3f}"
    )

    metrics = {k: round(v, 4) for k, v in features.items()}
    metrics.update(
        {
            "model_top1_prob": round(top3[0]["prob"], 4),
            "model_top2_prob": round(top3[1]["prob"], 4),
            "model_top3_prob": round(top3[2]["prob"], 4),
        }
    )
    return {
        "risk_level": risk_level,
        "confidence": round(confidence, 2),
        "pest_type": pest_type,
        "reason": reason,
        "engine": "convnext_tiny_ip102",
        "quality_score": round(quality, 3),
        "metrics": metrics,
        "suggestions": suggestions,
    }


def build_mock_leaf_image_bytes(risk_hint: str = "auto") -> bytes:
    width, height = 720, 480
    img = Image.new("RGB", (width, height), (55, 120, 55))
    draw = ImageDraw.Draw(img)

    draw.ellipse((120, 60, 640, 430), fill=(70, 150, 65), outline=(38, 95, 38), width=4)
    draw.line((360, 90, 360, 400), fill=(38, 95, 38), width=3)

    key = (risk_hint or "auto").strip().lower()
    if key == "auto":
        key = random.choice(["low", "medium", "high"])

    if key == "high":
        for _ in range(70):
            x = random.randint(150, 620)
            y = random.randint(90, 400)
            r = random.randint(4, 12)
            color = random.choice([(120, 60, 45), (95, 45, 40), (70, 45, 35)])
            draw.ellipse((x - r, y - r, x + r, y + r), fill=color)
    elif key == "medium":
        for _ in range(36):
            x = random.randint(160, 610)
            y = random.randint(95, 395)
            r = random.randint(3, 9)
            color = random.choice([(135, 120, 55), (120, 95, 50), (95, 90, 45)])
            draw.ellipse((x - r, y - r, x + r, y + r), fill=color)
    else:
        for _ in range(10):
            x = random.randint(170, 600)
            y = random.randint(100, 390)
            r = random.randint(2, 6)
            color = random.choice([(92, 140, 72), (80, 130, 68)])
            draw.ellipse((x - r, y - r, x + r, y + r), fill=color)

    output = BytesIO()
    img.save(output, format="PNG")
    return output.getvalue()
