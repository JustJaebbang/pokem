import os
import smtplib
import ssl
from email.message import EmailMessage
from fastapi import HTTPException


def mail_settings():
    host = os.getenv("SMTP_HOST", "").strip()
    sender = os.getenv("SMTP_FROM", "").strip()
    mode = os.getenv("SMTP_SECURITY", "starttls")
    if not host or not sender or mode not in ("starttls", "ssl"):
        raise HTTPException(503, "이메일 인증 발송 설정을 확인해주세요.")
    try:
        port = int(os.getenv("SMTP_PORT", "465" if mode == "ssl" else "587"))
        if not 1 <= port <= 65535: raise ValueError()
    except ValueError:
        raise HTTPException(503, "이메일 인증 발송 설정을 확인해주세요.") from None
    return host, port, sender, mode


def send_code(email, code):
    host, port, sender, mode = mail_settings()
    message = EmailMessage()
    message["Subject"] = "[포켐] 계정 찾기 인증번호"
    message["From"] = sender
    message["To"] = email
    message.set_content(f"포켐 인증번호는 {code}입니다.\n5분 안에 입력해주세요.\n본인이 요청하지 않았다면 이 메일을 무시해주세요.")
    try:
        transport = smtplib.SMTP_SSL if mode == "ssl" else smtplib.SMTP
        kwargs = {"context": ssl.create_default_context()} if mode == "ssl" else {}
        with transport(host, port, timeout=5, **kwargs) as smtp:
            if mode == "starttls": smtp.starttls(context=ssl.create_default_context())
            username = os.getenv("SMTP_USERNAME", "")
            if username: smtp.login(username, os.environ.get("SMTP_PASSWORD", ""))
            smtp.send_message(message)
    except (OSError, smtplib.SMTPException):
        raise HTTPException(503, "이메일을 보내지 못했습니다. 잠시 후 다시 시도해주세요.") from None
