import os
from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, Session, SQLModel, create_engine, select

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///veriscan.db")
engine = create_engine(DATABASE_URL)


def ahora():
    return datetime.now(timezone.utc)


class MarcaCalzado(SQLModel, table=True):
    __tablename__ = "marca_calzado"
    id_marca: Optional[int] = Field(default=None, primary_key=True)
    nombre_marca: str = Field(unique=True)


class EstandarCalzado(SQLModel, table=True):
    __tablename__ = "estandar_calzado"
    id_estandar: Optional[int] = Field(default=None, primary_key=True)
    id_marca: int = Field(foreign_key="marca_calzado.id_marca")
    modelo: str
    codigo_sku: str
    patrones_referencia: str = ""


class Usuario(SQLModel, table=True):
    __tablename__ = "usuario"
    id_usuario: Optional[int] = Field(default=None, primary_key=True)
    nombre_completo: str
    correo_electronico: str = Field(unique=True, index=True)
    contrasena_hash: str  # necesario para el login (no aparece en el diagrama ER)
    tipo_usuario: str = "B2C"  # B2C | B2B | Admin
    fecha_registro: datetime = Field(default_factory=ahora)


class Suscripcion(SQLModel, table=True):
    __tablename__ = "suscripcion"
    id_suscripcion: Optional[int] = Field(default=None, primary_key=True)
    id_usuario: int = Field(foreign_key="usuario.id_usuario")
    tipo_plan: str = "Freemium"  # Freemium | Pro | B2B
    fecha_inicio: datetime = Field(default_factory=ahora)
    fecha_fin: Optional[datetime] = None
    estado: str = "activa"


class Escaneo(SQLModel, table=True):
    __tablename__ = "escaneo"
    id_escaneo: Optional[int] = Field(default=None, primary_key=True)
    id_usuario: int = Field(foreign_key="usuario.id_usuario")
    id_estandar: Optional[int] = Field(default=None, foreign_key="estandar_calzado.id_estandar")
    fecha_escaneo: datetime = Field(default_factory=ahora)
    porcentaje_autenticidad: float
    resultado_evaluacion: str  # ORIGINAL | REPLICA | INCONCLUSO
    nota_grading: float  # graduación en %: autenticidad - umbral (positivo/negativo)
    tiempo_inferencia_seg: float


class ImagenEscaneada(SQLModel, table=True):
    __tablename__ = "imagen_escaneada"
    id_imagen: Optional[int] = Field(default=None, primary_key=True)
    id_escaneo: int = Field(foreign_key="escaneo.id_escaneo")
    zona_analisis: str  # etiqueta | suela | costuras
    url_almacenamiento: str


class Certificado(SQLModel, table=True):
    __tablename__ = "certificado"
    id_certificado: Optional[int] = Field(default=None, primary_key=True)
    id_escaneo: int = Field(foreign_key="escaneo.id_escaneo", unique=True)
    codigo_hash_unico: str = Field(unique=True, index=True)
    fecha_emision: datetime = Field(default_factory=ahora)
    url_pdf_certificado: str


def init_db():
    SQLModel.metadata.create_all(engine)
    with Session(engine) as s:
        if s.exec(select(MarcaCalzado)).first():
            return
        marcas = {n: MarcaCalzado(nombre_marca=n) for n in ["Nike", "Adidas", "Jordan", "New Balance", "Puma", "Converse"]}
        s.add_all(marcas.values())
        s.commit()
        for n, modelo, sku in [
            ("Nike", "Air Force 1 '07", "CW2288-111"),
            ("Adidas", "Samba OG", "B75806"),
            ("Jordan", "Air Jordan 1 Retro High OG", "555088-101"),
        ]:
            s.add(EstandarCalzado(id_marca=marcas[n].id_marca, modelo=modelo, codigo_sku=sku))
        s.commit()


def get_session():
    with Session(engine) as s:
        yield s
