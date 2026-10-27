import hashlib, hmac, io, os, secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from sqlmodel import Session, func, select

from . import ml
from .models import (Certificado, EstandarCalzado, Escaneo, ImagenEscaneada, MarcaCalzado,
                     Suscripcion, Usuario, get_session, init_db)

SECRET = os.getenv("JWT_SECRET", "cambia-este-secreto-de-al-menos-32-caracteres")
FREEMIUM_LIMITE = 30  # escaneos por mes
os.makedirs("uploads", exist_ok=True)

app = FastAPI(title="VeriScan API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
bearer = HTTPBearer()


@app.on_event("startup")
def startup():
    init_db()


# ---------- auth ----------
def hash_pw(p: str, salt: Optional[bytes] = None) -> str:
    salt = salt or os.urandom(16)
    return salt.hex() + ":" + hashlib.pbkdf2_hmac("sha256", p.encode(), salt, 100_000).hex()


def check_pw(p: str, stored: str) -> bool:
    return hmac.compare_digest(hash_pw(p, bytes.fromhex(stored.split(":")[0])), stored)


def token_for(u: Usuario) -> str:
    return jwt.encode({"sub": str(u.id_usuario), "exp": datetime.now(timezone.utc) + timedelta(days=30)}, SECRET, "HS256")


def current_user(c: HTTPAuthorizationCredentials = Depends(bearer), s: Session = Depends(get_session)) -> Usuario:
    try:
        uid = int(jwt.decode(c.credentials, SECRET, ["HS256"])["sub"])
    except Exception:
        raise HTTPException(401, "Sesión inválida")
    u = s.get(Usuario, uid)
    if not u:
        raise HTTPException(401, "Usuario no existe")
    return u


class RegisterIn(BaseModel):
    nombre: str
    email: str
    password: str
    rol: str = "B2C"


class LoginIn(BaseModel):
    email: str
    password: str


def plan_de(u: Usuario, s: Session) -> str:
    sub = s.exec(select(Suscripcion).where(Suscripcion.id_usuario == u.id_usuario, Suscripcion.estado == "activa")).first()
    return sub.tipo_plan if sub else "Freemium"


def user_out(u: Usuario, s: Session):
    return {"id": u.id_usuario, "nombre": u.nombre_completo, "email": u.correo_electronico,
            "tipo": u.tipo_usuario, "plan": plan_de(u, s)}


@app.post("/api/v1/auth/register")
def register(d: RegisterIn, s: Session = Depends(get_session)):
    email = d.email.strip().lower()
    if s.exec(select(Usuario).where(Usuario.correo_electronico == email)).first():
        raise HTTPException(409, "El correo ya está registrado")
    u = Usuario(nombre_completo=d.nombre.strip(), correo_electronico=email,
                contrasena_hash=hash_pw(d.password), tipo_usuario="B2B" if d.rol == "B2B" else "B2C")
    s.add(u); s.commit(); s.refresh(u)
    s.add(Suscripcion(id_usuario=u.id_usuario, tipo_plan="B2B" if u.tipo_usuario == "B2B" else "Freemium")); s.commit()
    return {"token": token_for(u), "usuario": user_out(u, s)}


@app.post("/api/v1/auth/login")
def login(d: LoginIn, s: Session = Depends(get_session)):
    u = s.exec(select(Usuario).where(Usuario.correo_electronico == d.email.strip().lower())).first()
    if not u or not check_pw(d.password, u.contrasena_hash):
        raise HTTPException(401, "Correo o contraseña incorrectos")
    return {"token": token_for(u), "usuario": user_out(u, s)}


@app.get("/api/v1/auth/me")
def me(u: Usuario = Depends(current_user), s: Session = Depends(get_session)):
    return user_out(u, s)


# ---------- catálogo ----------
@app.get("/api/v1/estandares")
def estandares(s: Session = Depends(get_session)):
    filas = s.exec(select(EstandarCalzado, MarcaCalzado).where(EstandarCalzado.id_marca == MarcaCalzado.id_marca)).all()
    return [{"id": e.id_estandar, "marca": m.nombre_marca, "modelo": e.modelo, "sku": e.codigo_sku} for e, m in filas]


# ---------- escaneos ----------
def escaneo_out(e: Escaneo, s: Session):
    cert = s.exec(select(Certificado).where(Certificado.id_escaneo == e.id_escaneo)).first()
    est = s.get(EstandarCalzado, e.id_estandar) if e.id_estandar else None
    marca = s.get(MarcaCalzado, est.id_marca) if est else None
    return {"id": e.id_escaneo, "modelo": f"{marca.nombre_marca} · {est.modelo}" if est else None,
            "autenticidad": e.porcentaje_autenticidad, "graduacion": e.nota_grading,
            "veredicto": e.resultado_evaluacion, "tiempo_s": e.tiempo_inferencia_seg,
            "fecha": e.fecha_escaneo.isoformat(),
            "certificado_hash": cert.codigo_hash_unico if cert else None,
            "certificado_pdf": cert.url_pdf_certificado if cert else None}


@app.post("/api/v1/escaneos/frame")
async def analizar_frame(imagen: UploadFile = File(...), u: Usuario = Depends(current_user)):
    try:
        return ml.frame(await imagen.read())
    except Exception:
        raise HTTPException(422, "Cuadro inválido")


@app.post("/api/v1/escaneos")
async def crear_escaneo(
    id_estandar: Optional[int] = Form(None),
    etiqueta: UploadFile = File(...), suela: UploadFile = File(...), costuras: UploadFile = File(...),
    u: Usuario = Depends(current_user), s: Session = Depends(get_session),
):
    if plan_de(u, s) == "Freemium":
        inicio_mes = datetime.now(timezone.utc).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        n = s.exec(select(func.count(Escaneo.id_escaneo)).where(
            Escaneo.id_usuario == u.id_usuario, Escaneo.fecha_escaneo >= inicio_mes)).one()
        if n >= FREEMIUM_LIMITE:
            raise HTTPException(402, f"Límite Freemium alcanzado ({FREEMIUM_LIMITE}/mes). Actualiza a Pro.")

    datos = {"etiqueta": await etiqueta.read(), "suela": await suela.read(), "costuras": await costuras.read()}
    try:
        r = ml.analizar(list(datos.values()))
    except Exception:
        raise HTTPException(422, "No se pudo procesar alguna imagen")

    e = Escaneo(id_usuario=u.id_usuario, id_estandar=id_estandar, porcentaje_autenticidad=r["autenticidad"],
                resultado_evaluacion=r["veredicto"], nota_grading=r["graduacion"], tiempo_inferencia_seg=r["tiempo_s"])
    s.add(e); s.commit(); s.refresh(e)
    for zona, b in datos.items():
        nombre = f"{e.id_escaneo}_{zona}_{secrets.token_hex(4)}.jpg"
        with open(f"uploads/{nombre}", "wb") as f:
            f.write(b)
        s.add(ImagenEscaneada(id_escaneo=e.id_escaneo, zona_analisis=zona, url_almacenamiento=f"/uploads/{nombre}"))
    s.commit()
    return {**escaneo_out(e, s), "modelo_entrenado": r["modelo_entrenado"]}


@app.get("/api/v1/escaneos")
def historial(u: Usuario = Depends(current_user), s: Session = Depends(get_session)):
    es = s.exec(select(Escaneo).where(Escaneo.id_usuario == u.id_usuario).order_by(Escaneo.fecha_escaneo.desc())).all()
    return [escaneo_out(e, s) for e in es]


# ---------- certificados ----------
@app.post("/api/v1/escaneos/{eid}/certificado")
def emitir(eid: int, u: Usuario = Depends(current_user), s: Session = Depends(get_session)):
    e = s.get(Escaneo, eid)
    if not e or e.id_usuario != u.id_usuario:
        raise HTTPException(404, "Escaneo no encontrado")
    if e.resultado_evaluacion != "ORIGINAL":
        raise HTTPException(400, "Solo se certifican productos verificados como originales")
    c = s.exec(select(Certificado).where(Certificado.id_escaneo == eid)).first()
    if not c:
        h = hashlib.sha256(f"{eid}|{e.id_usuario}|{e.porcentaje_autenticidad}|{secrets.token_hex(8)}".encode()).hexdigest()
        s.add(Certificado(id_escaneo=eid, codigo_hash_unico=h, url_pdf_certificado=f"/api/v1/certificados/{h}.pdf"))
        s.commit()
    return escaneo_out(e, s)


@app.get("/api/v1/certificados/{h}.pdf")
def certificado_pdf(h: str, s: Session = Depends(get_session)):
    c = s.exec(select(Certificado).where(Certificado.codigo_hash_unico == h)).first()
    if not c:
        raise HTTPException(404, "Certificado no encontrado")
    e = s.get(Escaneo, c.id_escaneo)
    modelo = escaneo_out(e, s)["modelo"] or "-"
    buf = io.BytesIO()
    p = canvas.Canvas(buf, pagesize=A4)
    y = 780
    p.setFont("Helvetica-Bold", 22); p.drawString(60, y, "Certificado de Autenticidad - VeriScan")
    p.setFont("Helvetica", 12)
    for linea in [f"Modelo: {modelo}", f"Veredicto: {e.resultado_evaluacion}",
                  f"Autenticidad: {e.porcentaje_autenticidad}%", f"Graduacion: {e.nota_grading:+.1f}%",
                  f"Fecha de emision: {c.fecha_emision:%Y-%m-%d %H:%M} UTC", "Codigo hash:", h[:32], h[32:]]:
        y -= 28; p.drawString(60, y, linea)
    p.save()
    return Response(buf.getvalue(), media_type="application/pdf")
