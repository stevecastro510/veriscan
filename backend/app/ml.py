import io, os, time

import torch
import torch.nn as nn
from PIL import Image, ImageFilter, ImageStat
from torchvision import models, transforms

WEIGHTS = os.getenv("MODEL_PATH", "models/veriscan.pt")
UMBRAL = 85.0  # % mínimo de autenticidad para considerar ORIGINAL

prep = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])


class VeriScanNet(nn.Module):
    """MobileNetV3-Small + cabeza de autenticidad (0-1)."""
    def __init__(self):
        super().__init__()
        m = models.mobilenet_v3_small(weights=None)
        self.features, self.pool = m.features, m.avgpool
        self.auth = nn.Linear(576, 1)

    def forward(self, x):
        return torch.sigmoid(self.auth(self.pool(self.features(x)).flatten(1)))


model = VeriScanNet().eval()
TRAINED = os.path.exists(WEIGHTS)
if TRAINED:
    model.load_state_dict(torch.load(WEIGHTS, map_location="cpu"))


def _score(img: Image.Image):
    """Devuelve (autenticidad %, nitidez 0-1) de una imagen."""
    img.thumbnail((640, 640))
    edges = ImageStat.Stat(img.convert("L").filter(ImageFilter.FIND_EDGES)).mean[0]
    nitidez = min(1.0, edges / 12)
    if TRAINED:
        with torch.no_grad():
            a = model(prep(img).unsqueeze(0)).item() * 100
    else:
        # Sin pesos entrenados: heurística de nitidez de bordes (solo demo del flujo).
        a = min(98.0, max(30.0, 45 + edges * 4))
    return a, nitidez


def _img(b: bytes) -> Image.Image:
    return Image.open(io.BytesIO(b)).convert("RGB")


def frame(b: bytes) -> dict:
    """Análisis rápido de un cuadro de la cámara en vivo (no se guarda)."""
    a, n = _score(_img(b))
    return {"autenticidad": round(a, 1), "graduacion": round(a - UMBRAL, 1), "nitidez": round(n, 2)}


def analizar(imagenes: list[bytes]) -> dict:
    t0 = time.time()
    a = sum(_score(_img(b))[0] for b in imagenes) / len(imagenes)
    veredicto = "ORIGINAL" if a >= UMBRAL else "REPLICA" if a < 60 else "INCONCLUSO"
    return {
        "autenticidad": round(a, 1),
        "graduacion": round(a - UMBRAL, 1),
        "veredicto": veredicto,
        "tiempo_s": round(time.time() - t0, 2),
        "modelo_entrenado": TRAINED,
    }
