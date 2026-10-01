import base64
import json
import logging
import os
import urllib.parse
import urllib.request
from abc import ABC, abstractmethod

from .phone import display_phone

logger = logging.getLogger("jeevandhara.otp")

# Twilio's Messages API endpoint.
_TWILIO_MESSAGES_URL = "https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"

# MSG91's OTP API endpoint (v5).
_MSG91_SEND_URL = "https://control.msg91.com/api/v5/otp"


def _otp_message(code: str) -> str:
    return (
        f"Your Jeevandhara verification code is {code}. "
        "It expires in 5 minutes. Do not share it with anyone."
    )


class SmsProvider(ABC):
    """Interface every SMS backend implements. Swap without touching routers."""

    @abstractmethod
    def send(self, phone: str, code: str) -> None:
        """Deliver `code` to the normalized `phone` (digits only, '91...')."""

    def send_verification(self, phone: str, code: str) -> None:
        # Sanitize: only ever log digits, never the code.
        logger.info("Sending OTP to %s", display_phone(phone))
        self.send(phone, code)


class TwilioSmsProvider(SmsProvider):
    """Twilio REST via the standard library — no SDK dependency required."""

    def __init__(self, account_sid: str, auth_token: str, from_number: str) -> None:
        self.account_sid = account_sid
        self.auth_token = auth_token
        self.from_number = from_number

    def send(self, phone: str, code: str) -> None:
        url = _TWILIO_MESSAGES_URL.format(sid=self.account_sid)
        payload = urllib.parse.urlencode(
            {
                "To": "+" + phone,
                "From": self.from_number,
                "Body": _otp_message(code),
            }
        ).encode("utf-8")
        credentials = base64.b64encode(
            f"{self.account_sid}:{self.auth_token}".encode("utf-8")
        ).decode("ascii")
        request = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Authorization": f"Basic {credentials}",
                "Content-Type": "application/x-www-form-urlencoded",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                if response.status not in (200, 201):
                    raise RuntimeError(f"Twilio returned HTTP {response.status}")
        except urllib.error.URLError as exc:  # type: ignore[attr-defined]
            raise RuntimeError(f"Twilio request failed: {exc}") from exc


class ConsoleSmsProvider(SmsProvider):
    """
    Prints the code to the console. Development/testing ONLY — gate via
    OTP_SMS_PROVIDER=console AND APP_ENV=development, otherwise refuse to load.
    """

    def send(self, phone: str, code: str) -> None:
        logger.warning(
            "DEV ONLY — OTP for %s: %s. Never enable OTP_SMS_PROVIDER=console in production.",
            display_phone(phone),
            code,
        )


class MSG91SmsProvider(SmsProvider):
    """
    MSG91 OTP API via the standard library — no SDK dependency.

    Sends OUR OWN generated code. MSG91 injects it into the configured OTP
    template (the template body must contain the OTP placeholder). Verification
    stays local (bcrypt hash in the DB), so we never ship plaintext codes out.
    """

    def __init__(self, auth_key: str, sender_id: str, template_id: str) -> None:
        self.auth_key = auth_key
        self.sender_id = sender_id
        self.template_id = template_id

    def send(self, phone: str, code: str) -> None:
        params = urllib.parse.urlencode(
            {
                "authkey": self.auth_key,
                "mobile": phone,
                "template_id": self.template_id,
                "otp": code,
                "otp_length": "6",
                "otp_expiry": "5",
            }
        )
        if self.sender_id:
            params += "&sender_id=" + urllib.parse.quote(self.sender_id)
        request = urllib.request.Request(
            f"{_MSG91_SEND_URL}?{params}",
            data=b"{}",
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                body = response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")
            raise RuntimeError(
                f"MSG91 returned HTTP {exc.code}: {detail[:300]}"
            ) from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"MSG91 request failed: {exc}") from exc

        try:
            payload = json.loads(body)
        except ValueError as exc:
            raise RuntimeError(
                f"MSG91 returned an invalid response: {body[:200]}"
            ) from exc

        if payload.get("type") != "success":
            raise RuntimeError(
                "MSG91 send failed: " + str(payload.get("message", payload))
            )


def _build_provider() -> SmsProvider | None:
    provider_name = os.getenv("OTP_SMS_PROVIDER", "").strip().lower()
    env = os.getenv("APP_ENV", "development").strip().lower()

    if provider_name == "console":
        if env == "production":
            raise RuntimeError("Console OTP provider is not allowed in production.")
        return ConsoleSmsProvider()

    if provider_name == "twilio":
        account_sid = os.getenv("TWILIO_ACCOUNT_SID", "").strip()
        auth_token = os.getenv("TWILIO_AUTH_TOKEN", "").strip()
        from_number = os.getenv("TWILIO_FROM_NUMBER", "").strip()
        if not (account_sid and auth_token and from_number):
            raise RuntimeError(
                "OTP_SMS_PROVIDER=twilio requires TWILIO_ACCOUNT_SID, "
                "TWILIO_AUTH_TOKEN and TWILIO_FROM_NUMBER."
            )
        return TwilioSmsProvider(account_sid, auth_token, from_number)

    if provider_name == "msg91":
        auth_key = os.getenv("MSG91_AUTH_KEY", "").strip()
        sender_id = os.getenv("MSG91_SENDER_ID", "").strip()
        template_id = os.getenv("MSG91_TEMPLATE_ID", "").strip()
        if not (auth_key and template_id):
            raise RuntimeError(
                "OTP_SMS_PROVIDER=msg91 requires MSG91_AUTH_KEY and MSG91_TEMPLATE_ID."
            )
        return MSG91SmsProvider(auth_key, sender_id, template_id)

    # No explicit provider: auto-select Twilio if fully configured, else dev console.
    if env != "production" and not provider_name:
        return ConsoleSmsProvider()
    return None


def get_sms_provider():
    """
    FastAPI dependency. Resolved once per request; override in tests via
    `app.dependency_overrides[get_sms_provider]` with a fake provider.
    """
    return _build_provider()