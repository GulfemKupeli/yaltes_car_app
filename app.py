import uuid, datetime as dt
from typing import List, Optional
import enum, os
import logging
from pathlib import Path
from fastapi.responses import JSONResponse
import traceback
import time
from fastapi import UploadFile, File
from fastapi.staticfiles import StaticFiles
import uuid as uuidlib
import shutil, os
from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from pydantic import BaseModel, EmailStr
from pydantic_settings import BaseSettings

from sqlalchemy import (create_engine, Column, String, Boolean, Enum, Text, Integer,
                        TIMESTAMP, ForeignKey, CheckConstraint, func, text, and_)
from sqlalchemy.dialects.postgresql import UUID as PGUUID, TSRANGE
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from passlib.hash import bcrypt

BASE_DIR = Path(__file__).parent
STATIC_DIR = BASE_DIR / "static"
UPLOAD_DIR = STATIC_DIR / "uploads"
STATIC_DIR.mkdir(exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="YALTES Car API")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

class Settings(BaseSettings):
    DATABASE_URL: str
    JWT_SECRET: str = "dev"
    class Config: env_file = ".env"

settings = Settings()

engine = create_engine(settings.DATABASE_URL, future=True, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
Base = declarative_base()

JWT_ALG = "HS256"
auth_scheme = HTTPBearer()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logging.info("STATIC_DIR = %s", STATIC_DIR.resolve())
logging.info("UPLOAD_DIR = %s", UPLOAD_DIR.resolve())


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
    retired = "retired"


class User(Base):
    __tablename__ = "users"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)   # <- BUNU KULLAN
    full_name = Column(String, nullable=False)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.user)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())


class Admin(Base):
    __tablename__ = "admins"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    full_name = Column(String, nullable=False)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.admin)
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

#tables
def bootstrap():
    Base.metadata.create_all(engine)
    # try to ensure needed extensions + exclusion constraint
    ddl = """
    DO $$
    BEGIN
      PERFORM 1 FROM pg_extension WHERE extname='pgcrypto';
      IF NOT FOUND THEN
        BEGIN
          CREATE EXTENSION pgcrypto;
        EXCEPTION WHEN insufficient_privilege THEN
          -- ignore, print a hint
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

def seed_admin(db: Session):
    email = "admin@yaltes.local"
    if not db.query(User).filter(User.email == email).first():
        u = User(
            email=email,
            full_name="Admin",
            password_hash=bcrypt.hash("admin123"),
            role=UserRole.admin,
        )
        db.add(u); db.commit()

with SessionLocal() as db:
    seed_admin(db)

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
    role: UserRole
    class Config: from_attributes = True

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

class VehicleOut(VehicleIn):
    id: uuid.UUID
    status: VehicleStatus
    class Config: from_attributes = True

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
    class Config: from_attributes = True

class BlockoutIn(BaseModel):
    vehicle_id: uuid.UUID
    starts_at: dt.datetime
    ends_at: dt.datetime
    reason: Optional[str] = None

class BlockoutOut(BlockoutIn):
    id: uuid.UUID
    class Config: from_attributes = True

class AdminLoginReq(BaseModel):
    email: str
    password: str


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

def create_token(user: User) -> str:
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role.value,
        "exp": dt.datetime.utcnow() + dt.timedelta(hours=8),
        "iat": dt.datetime.utcnow(),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=JWT_ALG)

def get_current_user(creds: HTTPAuthorizationCredentials = Depends(auth_scheme),
                     db: Session = Depends(get_db)) -> User:
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
    if user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin only")
    return user

# ================= Health =================
@app.get("/health")
def health(): return {"ok": True}

# giriş işlemleri
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

@app.post("/admin/login", response_model=TokenOut)
def admin_login(req: AdminLoginReq, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not bcrypt.verify(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email veya şifre hatalı")

    if user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin yetkisi yok")
    token = create_token(user)
    return TokenOut(access_token=token)
    
@app.middleware("http")
async def log_requests(request, call_next):
    start = time.time()
    response = await call_next(request)
    dur = (time.time() - start) * 1000
    logging.info("%s %s -> %s (%.1f ms)",
                 request.method, request.url.path, response.status_code, dur)
    return response

# Araçapi
@app.get("/vehicles", response_model=List[VehicleOut])
def list_vehicles(db: Session = Depends(get_db)):
    return db.query(Vehicle).order_by(Vehicle.brand, Vehicle.model).all()

@app.get("/vehicles/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(vehicle_id: uuid.UUID, db: Session = Depends(get_db)):
    v = db.get(Vehicle, vehicle_id)
    if not v: raise HTTPException(404, "Vehicle not found")
    return v

@app.post("/vehicles", response_model=VehicleOut)
def create_vehicle(data: VehicleIn, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    v = Vehicle(**data.dict())
    db.add(v); db.commit(); db.refresh(v)
    return v

@app.put("/vehicles/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(vehicle_id: uuid.UUID, data: VehicleUpdate, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    v = db.get(Vehicle, vehicle_id)
    if not v: raise HTTPException(404, "Vehicle not found")
    for k, val in data.dict(exclude_unset=True).items():
        setattr(v, k, val)
    db.commit(); db.refresh(v)
    return v

@app.delete("/vehicles/{vehicle_id}")
def delete_vehicle(vehicle_id: uuid.UUID, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    v = db.get(Vehicle, vehicle_id)
    if not v: raise HTTPException(404, "Vehicle not found")
    db.delete(v); db.commit()
    return {"deleted": True}

@app.post("/upload")
async def upload_image(file: UploadFile = File(...), request: Request = None):
    ext = Path(file.filename).suffix.lower()
    fname = f"{uuid.uuid4()}{ext}"
    dest = UPLOAD_DIR / fname
    with dest.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    base = str(request.base_url).rstrip("/")  
    return {"url": f"{base}/static/uploads/{fname}"}

# Statü
@app.get("/availability", response_model=List[VehicleOut])
def availability(frm: dt.datetime, to: dt.datetime, db: Session = Depends(get_db)):
    if to <= frm: raise HTTPException(400, "to must be after from")
    conflicts_sql = text("""
      WITH conflicts AS (
        SELECT DISTINCT vehicle_id
        FROM bookings
        WHERE status IN ('pending','approved') AND time_range && tstzrange(:frm, :to, '[)')
        UNION
        SELECT vehicle_id
        FROM vehicle_blockouts
        WHERE tstzrange(starts_at, ends_at, '[)') && tstzrange(:frm, :to, '[)')
      )
      SELECT id FROM vehicles
      WHERE status='active' AND id NOT IN (SELECT vehicle_id FROM conflicts)
    """)
    with db.bind.connect() as conn:
        rows = conn.execute(conflicts_sql, {"frm": frm, "to": to}).fetchall()
    ids = [r[0] for r in rows]
    if not ids: return []
    return db.query(Vehicle).filter(Vehicle.id.in_(ids)).all()

# Randevu
@app.post("/bookings", response_model=BookingOut)
def create_booking(data: BookingIn, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if data.ends_at <= data.starts_at:
        raise HTTPException(400, "ends_at must be after starts_at")
    with db.bind.connect() as conn:
        tr = conn.execute(text("SELECT tstzrange(:s, :e, '[)')"), {"s": data.starts_at, "e": data.ends_at}).scalar()
    b = Booking(user_id=current.id, vehicle_id=data.vehicle_id,
                starts_at=data.starts_at, ends_at=data.ends_at,
                time_range=tr, purpose=data.purpose)
    db.add(b)
    try:
        db.commit(); db.refresh(b)
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
    if current.role != UserRole.admin:
        q = q.filter(Booking.user_id == current.id)
    return q.order_by(Booking.starts_at.desc()).all()

@app.get("/bookings/me", response_model=List[BookingOut])
def my_bookings(current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Booking)\
             .filter(Booking.user_id == current.id)\
             .order_by(Booking.starts_at.desc()).all()

def _set_booking_status(db: Session, bid: uuid.UUID, new_status: BookingStatus) -> Booking:
    b = db.get(Booking, bid)
    if not b: raise HTTPException(404, "Booking not found")
    b.status = new_status
    db.commit(); db.refresh(b)
    return b

@app.post("/bookings/{booking_id}/approve", response_model=BookingOut)
def approve_booking(booking_id: uuid.UUID, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    return _set_booking_status(db, booking_id, BookingStatus.approved)

@app.post("/bookings/{booking_id}/cancel", response_model=BookingOut)
def cancel_booking(booking_id: uuid.UUID, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    b = db.get(Booking, booking_id)
    if not b: raise HTTPException(404, "Booking not found")
    if current.role != UserRole.admin and b.user_id != current.id:
        raise HTTPException(403, "Not allowed")
    return _set_booking_status(db, booking_id, BookingStatus.canceled)

@app.post("/bookings/{booking_id}/complete", response_model=BookingOut)
def complete_booking(booking_id: uuid.UUID, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    return _set_booking_status(db, booking_id, BookingStatus.completed)

# admin
@app.post("/vehicle-blockouts", response_model=BlockoutOut)
def create_blockout(data: BlockoutIn, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    if data.ends_at <= data.starts_at:
        raise HTTPException(400, "ends_at must be after starts_at")
    bo = VehicleBlockout(**data.dict())
    db.add(bo); db.commit(); db.refresh(bo)
    return bo

@app.get("/vehicle-blockouts", response_model=List[BlockoutOut])
def list_blockouts(_: User = Depends(admin_required), db: Session = Depends(get_db)):
    return db.query(VehicleBlockout).order_by(VehicleBlockout.starts_at.desc()).all()

@app.delete("/vehicle-blockouts/{blockout_id}")
def delete_blockout(blockout_id: uuid.UUID, _: User = Depends(admin_required), db: Session = Depends(get_db)):
    bo = db.get(VehicleBlockout, blockout_id)
    if not bo: raise HTTPException(404, "Blockout not found")
    db.delete(bo); db.commit()
    return {"deleted": True}
