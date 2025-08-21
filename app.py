import os
import uuid
import datetime as dt
import logging
import time
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Depends, status, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.staticfiles import StaticFiles
from jose import jwt, JWTError
from pydantic import BaseModel, EmailStr
from pydantic_settings import BaseSettings

from sqlalchemy import (
    create_engine, Column, String, Boolean, Enum, Text, Integer, Float,
    TIMESTAMP, ForeignKey, CheckConstraint, func, text, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID, TSRANGE
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from passlib.hash import bcrypt

import shutil

# ----------------------------- Firebase (opsiyonel) -----------------------------
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except Exception:
    firebase_admin = None
    credentials = None
    messaging = None

# --------------------------------------------------------------------------------
# Paths / Static
# --------------------------------------------------------------------------------
BASE_DIR = Path(__file__).parent
STATIC_DIR = BASE_DIR / "static"
UPLOAD_DIR = STATIC_DIR / "uploads"
STATIC_DIR.mkdir(exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="YALTES Car API")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# --------------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------------
class Settings(BaseSettings):
    DATABASE_URL: str
    JWT_SECRET: str = "dev"
    # Firebase hizmet hesabı dosya yolu (opsiyonel)
    FIREBASE_CREDENTIALS_FILE: Optional[str] = None
    FIREBASE_CREDENTIALS: Optional[str] = None  # eski isim
    class Config:
        env_file = ".env"

settings = Settings()

# --------------------------------------------------------------------------------
# DB
# --------------------------------------------------------------------------------
engine = create_engine(settings.DATABASE_URL, future=True, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
Base = declarative_base()

# --------------------------------------------------------------------------------
# Logging
# --------------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logging.info("STATIC_DIR = %s", STATIC_DIR.resolve())
logging.info("UPLOAD_DIR = %s", UPLOAD_DIR.resolve())

# --------------------------------------------------------------------------------
# Firebase init (tek ve opsiyonel)
# --------------------------------------------------------------------------------
FCM_READY = False
if firebase_admin:
    cred_path = settings.FIREBASE_CREDENTIALS_FILE or settings.FIREBASE_CREDENTIALS
    if cred_path and Path(cred_path).exists():
        try:
            firebase_admin.initialize_app(credentials.Certificate(cred_path))
            FCM_READY = True
            logging.info("Firebase Admin SDK initialized.")
        except Exception as e:
            logging.warning("Firebase init failed: %s", e)
    else:
        logging.warning("Firebase disabled (credentials missing).")
else:
    logging.warning("FCM disabled (firebase_admin not installed)")

# --------------------------------------------------------------------------------
# Auth
# --------------------------------------------------------------------------------
JWT_ALG = "HS256"
auth_scheme = HTTPBearer()

# --------------------------------------------------------------------------------
# Enums
# --------------------------------------------------------------------------------
import enum

class UserRole(str, enum.Enum):
    user = "user"
    admin = "admin"

class BookingStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    canceled = "canceled"
    completed = "completed"

class VehicleStatus(str, enum.Enum):
    active = "active"
    maintenance = "maintenance"

# --------------------------------------------------------------------------------
# Models
# --------------------------------------------------------------------------------
class User(Base):
    __tablename__ = "users"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    full_name = Column(String, nullable=False)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.user)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class Vehicle(Base):
    __tablename__ = "vehicles"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    plate = Column(String, unique=True, nullable=False)
    brand = Column(String, nullable=False)
    model = Column(String, nullable=False)
    color = Column(String)
    model_year = Column(Integer)
    seats = Column(Integer)
    fuel_type = Column(String)
    transmission = Column(String)
    status = Column(Enum(VehicleStatus), nullable=False, default=VehicleStatus.active)
    current_odometer = Column(Integer)
    image_url = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    last_location_name = Column(String, nullable=False)
    last_location_lat = Column(Float, nullable=False)
    last_location_lng = Column(Float, nullable=False)
    last_location_updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class VehicleBlockout(Base):
    __tablename__ = "vehicle_blockouts"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vehicle_id = Column(PGUUID(as_uuid=True), ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False)
    starts_at = Column(TIMESTAMP(timezone=True), nullable=False)
    ends_at = Column(TIMESTAMP(timezone=True), nullable=False)
    reason = Column(Text)
    __table_args__ = (CheckConstraint("ends_at > starts_at", name="blockout_valid"),)

class Booking(Base):
    __tablename__ = "bookings"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    vehicle_id = Column(PGUUID(as_uuid=True), ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False)
    starts_at = Column(TIMESTAMP(timezone=True), nullable=False)
    ends_at = Column(TIMESTAMP(timezone=True), nullable=False)
    time_range = Column(TSRANGE, nullable=False)
    status = Column(Enum(BookingStatus), nullable=False, default=BookingStatus.pending)
    purpose = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    __table_args__ = (CheckConstraint("ends_at > starts_at", name="booking_valid"),)

class DeviceToken(Base):
    __tablename__ = "device_tokens"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token = Column(Text, nullable=False)
    platform = Column(String, nullable=True)  # android | ios | web | other
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    __table_args__ = (UniqueConstraint('user_id', 'token', name='uq_user_token'),)

# --------------------------------------------------------------------------------
# Bootstrap / DDL
# --------------------------------------------------------------------------------
def bootstrap():
    Base.metadata.create_all(engine)
    ddl = """
    DO $$
    BEGIN
      PERFORM 1 FROM pg_extension WHERE extname='pgcrypto';
      IF NOT FOUND THEN
        BEGIN
          CREATE EXTENSION pgcrypto;
        EXCEPTION WHEN insufficient_privilege THEN
          RAISE NOTICE 'Need superuser to CREATE EXTENSION pgcrypto';
        END;
      END IF;

      PERFORM 1 FROM pg_extension WHERE extname='btree_gist';
      IF NOT FOUND THEN
        BEGIN
          CREATE EXTENSION btree_gist;
        EXCEPTION WHEN insufficient_privilege THEN
          RAISE NOTICE 'Need superuser to CREATE EXTENSION btree_gist';
        END;
      END IF;

      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='no_overlapping_approved_bookings') THEN
        BEGIN
          ALTER TABLE bookings
          ADD CONSTRAINT no_overlapping_approved_bookings
          EXCLUDE USING gist (
            vehicle_id WITH =,
            time_range WITH &&
          )
          WHERE (status IN ('pending','approved'));
        EXCEPTION WHEN undefined_object THEN
          RAISE NOTICE 'btree_gist missing; run CREATE EXTENSION btree_gist as superuser.';
        END;
      END IF;
    END$$;
    """
    with engine.connect() as conn:
        conn.execute(text(ddl))
        conn.commit()

bootstrap()

# Seed admin
def seed_admin(db: Session):
    email = "admin@yaltes.local"
    if not db.query(User).filter(User.email == email).first():
        u = User(
            email=email,
            full_name="Admin",
            password_hash=bcrypt.hash("admin123"),
        )
        db.add(u); db.commit()

with SessionLocal() as db:
    seed_admin(db)

# --------------------------------------------------------------------------------
# Schemas (Pydantic)
# --------------------------------------------------------------------------------
class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str

class LoginIn(BaseModel):
    email: str
    password: str

class UserOut(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str
    role: UserRole = UserRole.user
    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None

class VehicleIn(BaseModel):
    plate: str
    brand: str
    model: str
    color: Optional[str] = None
    model_year: Optional[int] = None
    seats: Optional[int] = None
    fuel_type: Optional[str] = None
    transmission: Optional[str] = None
    current_odometer: Optional[int] = None
    image_url: Optional[str] = None
    last_location_name: str
    last_location_lat: float
    last_location_lng: float

class VehicleUpdate(BaseModel):
    plate: Optional[str] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    color: Optional[str] = None
    model_year: Optional[int] = None
    seats: Optional[int] = None
    fuel_type: Optional[str] = None
    transmission: Optional[str] = None
    current_odometer: Optional[int] = None
    image_url: Optional[str] = None
    status: Optional[VehicleStatus] = None
    last_location_name: Optional[str] = None
    last_location_lat: Optional[float] = None
    last_location_lng: Optional[float] = None

class VehicleOut(VehicleIn):
    id: uuid.UUID
    status: VehicleStatus = VehicleStatus.active
    last_location_updated_at: Optional[dt.datetime] = None
    class Config:
        from_attributes = True

class BookingIn(BaseModel):
    vehicle_id: uuid.UUID
    starts_at: dt.datetime
    ends_at: dt.datetime
    purpose: Optional[str] = None

class BookingOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    vehicle_id: uuid.UUID
    starts_at: dt.datetime
    ends_at: dt.datetime
    status: BookingStatus
    purpose: Optional[str] = None
    class Config:
        from_attributes = True

class BlockoutIn(BaseModel):
    vehicle_id: uuid.UUID
    starts_at: dt.datetime
    ends_at: dt.datetime
    reason: Optional[str] = None

class BlockoutOut(BlockoutIn):
    id: uuid.UUID
    class Config:
        from_attributes = True

class AdminLoginReq(BaseModel):
    email: str
    password: str

class BookingWithNamesOut(BaseModel):
    id: uuid.UUID
    status: BookingStatus
    starts_at: dt.datetime
    ends_at: dt.datetime
    purpose: Optional[str] = None
    user_id: uuid.UUID
    user_full_name: str
    user_email: EmailStr
    vehicle_id: uuid.UUID
    vehicle_plate: str
    vehicle_brand: str
    vehicle_model: str
    class Config:
        from_attributes = True

class DeviceIn(BaseModel):
    token: str
    platform: Optional[str] = None  # android | ios | web | other

# --------------------------------------------------------------------------------
# Middleware / DI
# --------------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request, call_next):
    start = time.time()
    response = await call_next(request)
    dur = (time.time() - start) * 1000
    logging.info("%s %s -> %s (%.1f ms)", request.method, request.url.path, response.status_code, dur)
    return response

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_token(user: User) -> str:
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "role": UserRole.user.value if not hasattr(user, "role") or user.role is None else user.role.value,
        "exp": dt.datetime.utcnow() + dt.timedelta(hours=8),
        "iat": dt.datetime.utcnow(),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=JWT_ALG)

def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(auth_scheme),
    db: Session = Depends(get_db),
) -> User:
    token = creds.credentials
    try:
        data = jwt.decode(token, settings.JWT_SECRET, algorithms=[JWT_ALG])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    uid = data.get("sub")
    user = db.get(User, uuid.UUID(uid)) if uid else None
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user

def admin_required(user: User = Depends(get_current_user)) -> User:
    # şu an tek User tablosu var; admin check gerekiyorsa role alanını admin yap
    if getattr(user, "role", UserRole.user) != UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin only")
    return user

# --------------------------------------------------------------------------------
# FCM helpers
# --------------------------------------------------------------------------------
def _fcm_enabled() -> bool:
    return bool(FCM_READY and messaging)

def _send_push(tokens: list[str], title: str, body: str, data: Optional[dict] = None):
    if not tokens or not _fcm_enabled():
        return
    try:
        msg = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
        )
        resp = messaging.send_multicast(msg)
        logging.info("FCM sent: success=%s failure=%s", resp.success_count, resp.failure_count)
    except Exception as e:
        logging.exception("FCM error: %s", e)

def _notify_admins_new_booking(db: Session, booking: Booking):
    admin_ids = [u.id for u in db.query(User).filter(User.is_active == True).all()]  # tüm aktif kullanıcılar (istersen role==admin filtrele)
    if not admin_ids:
        return
    tokens = [t.token for t in db.query(DeviceToken).filter(DeviceToken.user_id.in_(admin_ids)).all()]
    if not tokens:
        return
    title = "Yeni rezervasyon"
    body = f"{booking.starts_at.strftime('%d.%m %H:%M')} - {booking.ends_at.strftime('%d.%m %H:%M')} aralığı için talep"
    _send_push(tokens, title, body, data={"booking_id": booking.id, "vehicle_id": booking.vehicle_id})

def _notify_user_status_change(db: Session, booking: Booking):
    tokens = [t.token for t in db.query(DeviceToken).filter(DeviceToken.user_id == booking.user_id).all()]
    if not tokens:
        return
    if booking.status == BookingStatus.approved:
        title, body = "Rezervasyon onaylandı", "Rezervasyon talebiniz onaylandı."
    elif booking.status == BookingStatus.canceled:
        title, body = "Rezervasyon iptal edildi", "Rezervasyon talebiniz iptal edildi."
    elif booking.status == BookingStatus.completed:
        title, body = "Rezervasyon tamamlandı", "Kullanım tamamlandı."
    else:
        title, body = "Rezervasyon güncellendi", f"Durum: {booking.status.value}"
    _send_push(tokens, title, body, data={"booking_id": booking.id})

# --------------------------------------------------------------------------------
# Utils
# --------------------------------------------------------------------------------
def _ensure_utc(d: dt.datetime) -> dt.datetime:
    return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)

def _has_conflict(db: Session, vehicle_id: uuid.UUID, s: dt.datetime, e: dt.datetime) -> bool:
    row = db.execute(text("""
      SELECT 1
      FROM bookings
      WHERE vehicle_id = :vid
        AND status IN ('pending','approved')
        AND time_range && tstzrange(:s, :e, '[)')
      LIMIT 1
    """), {"vid": str(vehicle_id), "s": s, "e": e}).first()
    if row:
        return True
    row2 = db.execute(text("""
      SELECT 1
      FROM vehicle_blockouts
      WHERE vehicle_id = :vid
        AND tstzrange(starts_at, ends_at, '[)') && tstzrange(:s, :e, '[)')
      LIMIT 1
    """), {"vid": str(vehicle_id), "s": s, "e": e}).first()
    return bool(row2)

# --------------------------------------------------------------------------------
# Health
# --------------------------------------------------------------------------------
@app.get("/health")
def health():
    return {"ok": True}

# --------------------------------------------------------------------------------
# Auth / Users
# --------------------------------------------------------------------------------
@app.post("/auth/register", response_model=UserOut)
def register(data: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(400, "Email already registered")
    hashed = bcrypt.hash(data.password)
    u = User(email=data.email, password_hash=hashed, full_name=data.full_name)
    db.add(u); db.commit(); db.refresh(u)
    return u

@app.post("/auth/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    logging.info("Login attempt: %s", data.email)
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not bcrypt.verify(data.password, user.password_hash):
        logging.warning("Invalid credentials for %s", data.email)
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_token(user)
    logging.info("Login success: %s", data.email)
    return TokenOut(access_token=token)

@app.get("/me", response_model=UserOut)
def me(current: User = Depends(get_current_user)):
    return current

@app.put("/me", response_model=UserOut)
def update_me(data: UserUpdate, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if data.email and data.email != current.email:
        exists = db.query(User).filter(User.email == data.email).first()
        if exists:
            raise HTTPException(status_code=400, detail="E-posta zaten kayıtlı")

    if data.full_name is not None:
        current.full_name = data.full_name.strip()
    if data.email is not None:
        current.email = data.email.strip()
    if data.password:
        current.password_hash = bcrypt.hash(data.password)

    db.commit(); db.refresh(current)
    return current

# --------------------------------------------------------------------------------
# Devices (Push)
# --------------------------------------------------------------------------------
@app.post("/devices/register")
def register_device(data: DeviceIn, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = db.query(DeviceToken).filter_by(user_id=current.id, token=data.token).first()
    if row:
        if data.platform and row.platform != data.platform:
            row.platform = data.platform
            db.commit()
        return {"ok": True}
    d = DeviceToken(user_id=current.id, token=data.token, platform=(data.platform or "other"))
    db.add(d); db.commit()
    return {"ok": True}

@app.post("/devices/unregister")
def unregister_device(data: DeviceIn, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    tok = db.query(DeviceToken).filter(DeviceToken.user_id == current.id,
                                       DeviceToken.token == data.token).first()
    if tok:
        db.delete(tok); db.commit()
    return {"ok": True}

# --------------------------------------------------------------------------------
# Vehicles
# --------------------------------------------------------------------------------
@app.get("/vehicles", response_model=List[VehicleOut])
def list_vehicles(db: Session = Depends(get_db)):
    return db.query(Vehicle).order_by(Vehicle.brand, Vehicle.model).all()

@app.get("/vehicles/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(vehicle_id: uuid.UUID, db: Session = Depends(get_db)):
    v = db.get(Vehicle, vehicle_id)
    if not v:
        raise HTTPException(404, "Vehicle not found")
    return v

@app.post("/vehicles", response_model=VehicleOut)
def create_vehicle(data: VehicleIn, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    v = Vehicle(**data.dict())
    db.add(v); db.commit(); db.refresh(v)
    return v

@app.put("/vehicles/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(vehicle_id: uuid.UUID, data: VehicleUpdate, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    v = db.get(Vehicle, vehicle_id)
    if not v:
        raise HTTPException(404, "Vehicle not found")
    payload = data.dict(exclude_unset=True)
    for k, val in payload.items():
        setattr(v, k, val)
    if any(k in payload for k in ("last_location_name", "last_location_lat", "last_location_lng")):
        v.last_location_updated_at = func.now()
    db.commit(); db.refresh(v)
    return v

@app.delete("/vehicles/{vehicle_id}")
def delete_vehicle(vehicle_id: uuid.UUID, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    v = db.get(Vehicle, vehicle_id)
    if not v:
        raise HTTPException(404, "Vehicle not found")
    db.delete(v); db.commit()
    return {"deleted": True}

# Takvim (araç için, ay bazlı)
@app.get("/vehicles/{vehicle_id}/calendar")
def vehicle_calendar(vehicle_id: uuid.UUID, month: str, db: Session = Depends(get_db)):
    try:
        year_str, month_str = month.split("-")
        year = int(year_str); mon = int(month_str)
        assert 1 <= mon <= 12
    except Exception:
        raise HTTPException(status_code=400, detail="month must be YYYY-MM")

    start = dt.datetime(year, mon, 1, tzinfo=dt.timezone.utc)
    end = dt.datetime(year + (1 if mon == 12 else 0), (1 if mon == 12 else mon + 1), 1, tzinfo=dt.timezone.utc)

    bookings = (
        db.query(Booking)
        .filter(
            Booking.vehicle_id == vehicle_id,
            Booking.status.in_([BookingStatus.pending, BookingStatus.approved]),
            Booking.starts_at < end,
            Booking.ends_at > start,
        ).all()
    )
    blockouts = (
        db.query(VehicleBlockout)
        .filter(
            VehicleBlockout.vehicle_id == vehicle_id,
            VehicleBlockout.starts_at < end,
            VehicleBlockout.ends_at > start,
        ).all()
    )

    busy = [
        {"start": b.starts_at.isoformat(), "end": b.ends_at.isoformat(), "type": "booking"}
        for b in bookings
    ] + [
        {"start": bo.starts_at.isoformat(), "end": bo.ends_at.isoformat(), "type": "blockout"}
        for bo in blockouts
    ]
    return {"busy": busy}

# --------------------------------------------------------------------------------
# Upload
# --------------------------------------------------------------------------------
@app.post("/upload")
async def upload_image(file: UploadFile = File(...), request: Request = None):
    ext = Path(file.filename).suffix.lower()
    fname = f"{uuid.uuid4()}{ext}"
    dest = UPLOAD_DIR / fname
    with dest.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    base = str(request.base_url).rstrip("/")
    return {"url": f"{base}/static/uploads/{fname}"}

# --------------------------------------------------------------------------------
# Availability / Bookings / Blockouts
# --------------------------------------------------------------------------------
@app.get("/availability", response_model=List[VehicleOut])
def availability(frm: dt.datetime, to: dt.datetime, db: Session = Depends(get_db)):
    if to <= frm:
        raise HTTPException(400, "to must be after from")

    frm = frm.replace(tzinfo=None)
    to = to.replace(tzinfo=None)

    conflicts_sql = text("""
        WITH conflicts AS (
            SELECT DISTINCT vehicle_id
            FROM bookings
            WHERE status IN ('pending','approved') AND time_range && tsrange(:frm, :to, '[)')
            UNION
            SELECT vehicle_id
            FROM vehicle_blockouts
            WHERE tsrange(starts_at, ends_at, '[)') && tsrange(:frm, :to, '[)')
        )
        SELECT id FROM vehicles
        WHERE status='active' AND id NOT IN (SELECT vehicle_id FROM conflicts)
    """)

    with db.bind.connect() as conn:
        rows = conn.execute(conflicts_sql, {"frm": frm, "to": to}).fetchall()

    ids = [r[0] for r in rows]
    if not ids:
        return []
    return db.query(Vehicle).filter(Vehicle.id.in_(ids)).all()

@app.post("/bookings", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
def create_booking(data: BookingIn, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    s = _ensure_utc(data.starts_at)
    e = _ensure_utc(data.ends_at)
    if e <= s:
        raise HTTPException(400, "ends_at must be after starts_at")
    if _has_conflict(db, data.vehicle_id, s, e):
        raise HTTPException(409, "Çakışan rezervasyon veya blokaj.")

    with db.bind.connect() as conn:
        tr = conn.execute(text("SELECT tstzrange(:s, :e, '[)')"), {"s": s, "e": e}).scalar()

    b = Booking(
        user_id=current.id,
        vehicle_id=data.vehicle_id,
        starts_at=s,
        ends_at=e,
        time_range=tr,
        purpose=data.purpose,
    )
    db.add(b)
    try:
        db.commit(); db.refresh(b)
        _notify_admins_new_booking(db, b)
    except Exception as ex:
        db.rollback()
        msg = str(ex)
        if "23P01" in msg or "no_overlapping_approved_bookings" in msg:
            raise HTTPException(409, "Çakışan rezervasyon veya blokaj.")
        raise
    return b

@app.get("/bookings", response_model=List[BookingOut])
def list_bookings(current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    q = db.query(Booking)
    if getattr(current, "role", UserRole.user) != UserRole.admin:
        q = q.filter(Booking.user_id == current.id)
    return q.order_by(Booking.starts_at.desc()).all()

@app.get("/bookings/me", response_model=List[BookingOut])
def my_bookings(current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Booking).filter(Booking.user_id == current.id).order_by(Booking.starts_at.desc()).all()

def _set_booking_status(db: Session, bid: uuid.UUID, new_status: BookingStatus) -> Booking:
    b = db.get(Booking, bid)
    if not b:
        raise HTTPException(404, "Booking not found")
    b.status = new_status
    db.commit(); db.refresh(b)
    return b

@app.post("/bookings/{booking_id}/approve", response_model=BookingOut)
def approve_booking(booking_id: uuid.UUID, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    b = _set_booking_status(db, booking_id, BookingStatus.approved)
    _notify_user_status_change(db, b)
    return b

@app.post("/bookings/{booking_id}/cancel", response_model=BookingOut)
def cancel_booking(booking_id: uuid.UUID, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    b = db.get(Booking, booking_id)
    if not b:
        raise HTTPException(404, "Booking not found")
    if getattr(current, "role", UserRole.user) != UserRole.admin and b.user_id != current.id:
        raise HTTPException(403, "Not allowed")
    b = _set_booking_status(db, booking_id, BookingStatus.canceled)
    _notify_user_status_change(db, b)
    return b

@app.post("/bookings/{booking_id}/complete", response_model=BookingOut)
def complete_booking(booking_id: uuid.UUID, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    b = _set_booking_status(db, booking_id, BookingStatus.completed)
    _notify_user_status_change(db, b)
    return b

@app.post("/vehicle-blockouts", response_model=BlockoutOut)
def create_blockout(data: BlockoutIn, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    if data.ends_at <= data.starts_at:
        raise HTTPException(400, "ends_at must be after starts_at")
    bo = VehicleBlockout(**data.dict())
    db.add(bo); db.commit(); db.refresh(bo)
    return bo

@app.get("/vehicle-blockouts", response_model=List[BlockoutOut])
def list_blockouts(current: User = Depends(admin_required), db: Session = Depends(get_db)):
    return db.query(VehicleBlockout).order_by(VehicleBlockout.starts_at.desc()).all()

@app.delete("/vehicle-blockouts/{blockout_id}")
def delete_blockout(blockout_id: uuid.UUID, current: User = Depends(admin_required), db: Session = Depends(get_db)):
    bo = db.get(VehicleBlockout, blockout_id)
    if not bo:
        raise HTTPException(404, "Blockout not found")
    db.delete(bo); db.commit()
    return {"deleted": True}

@app.get("/admin/bookings", response_model=List[BookingWithNamesOut])
def admin_bookings(current: User = Depends(admin_required), db: Session = Depends(get_db)):
    rows = (
        db.query(Booking, User, Vehicle)
        .join(User, Booking.user_id == User.id)
        .join(Vehicle, Booking.vehicle_id == Vehicle.id)
        .order_by(Booking.starts_at.desc())
        .all()
    )
    return [
        BookingWithNamesOut(
            id=b.id, status=b.status, starts_at=b.starts_at, ends_at=b.ends_at, purpose=b.purpose,
            user_id=u.id, user_full_name=u.full_name, user_email=u.email,
            vehicle_id=v.id, vehicle_plate=v.plate, vehicle_brand=v.brand, vehicle_model=v.model
        ) for (b, u, v) in rows
    ]

@app.get("/admin/inuse")
def vehicles_in_use(current: User = Depends(admin_required), db: Session = Depends(get_db)):
    now = func.now()
    rows = (
        db.query(Booking, User, Vehicle)
        .join(User, Booking.user_id == User.id)
        .join(Vehicle, Booking.vehicle_id == Vehicle.id)
        .filter(
            Booking.status.in_([BookingStatus.pending, BookingStatus.approved]),
            Booking.starts_at <= now,
            Booking.ends_at > now,
        )
        .order_by(Booking.ends_at.asc())
        .all()
    )
    return [{
        "booking_id": b.id,
        "until": b.ends_at,
        "user": {"id": u.id, "name": u.full_name, "email": u.email},
        "vehicle": {"id": v.id, "plate": v.plate, "brand": v.brand, "model": v.model},
    } for b, u, v in rows]

