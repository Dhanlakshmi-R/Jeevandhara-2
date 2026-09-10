from pydantic import BaseModel, EmailStr
from .models import UserRole


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: UserRole = UserRole.farmer
    phone: str | None = None
    location: str | None = None


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    role: UserRole
    phone: str | None = None
    location: str | None = None

    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
