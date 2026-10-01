from pydantic import BaseModel, EmailStr, Field
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
    phone_verified: bool = False
    auth_provider: str = "password"
    provider_user_id: str | None = None
    profile_image: str | None = None
    profile_complete: bool = True
    location: str | None = None

    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResult(Token):
    """Returned by every login path (password, Google, OTP) after a successful sign-in.

    `profile_complete=False` tells the app to show the onboarding/profile-completion
    screen before entering the app (new Google/OTP users).
    """
    profile_complete: bool
    user: UserOut


class GoogleAuthRequest(BaseModel):
    id_token: str


class OtpSendRequest(BaseModel):
    phone: str = Field(..., description="Indian mobile number, e.g. 9876543210, +919876543210 or 919876543210")


class OtpVerifyRequest(BaseModel):
    phone: str
    otp: str = Field(..., min_length=4, max_length=8)


class ProfileCompleteRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    role: UserRole = UserRole.farmer
    phone: str | None = None
    location: str | None = None
    profile_image: str | None = None
