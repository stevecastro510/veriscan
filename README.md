# VeriScan v2

## Backend
cd backend
python -m venv venv && venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000      # docs: http://localhost:8000/docs

SQLite por defecto. PostgreSQL: docker compose up -d y
set DATABASE_URL=postgresql://veriscan:veriscan@localhost:5432/veriscan

## App
Copia `app/lib/*` y `app/pubspec.yaml` sobre tu proyecto Flutter (carpeta app), luego:
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000      # emulador
flutter run --dart-define=API_URL=http://IP_DE_TU_PC:8000   # celular/tablet físico

AndroidManifest.xml: permisos INTERNET y CAMERA, y android:usesCleartextTraffic="true".

## Modelo
Sin backend/models/veriscan.pt corre en modo demo (heurística de nitidez). Para entrenar:
backend/data/original/*.jpg y backend/data/replica/*.jpg, luego python train.py
