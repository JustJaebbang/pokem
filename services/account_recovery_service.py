"""Single-process, bounded, expiring recovery challenges. Never log codes or passwords."""
import hashlib
import hmac
import secrets
import threading
import time
from uuid import uuid4
from fastapi import HTTPException
from security import hash_password, _jwt_secret
from services import recovery_mail_service

_lock = threading.RLock()
_challenges = {}
_rates = {}


def _digest(value):
    return hmac.new(_jwt_secret().encode(), value.encode(), hashlib.sha256).hexdigest()


def _binding(row):
    return _digest(row['user_id'] + '\0' + row['user_password'] + '\0' + row['user_email'].strip().lower())


def _accounts(db, email, user_id=None, locked=False):
    sql = """SELECT user_id,user_email,user_password FROM `user` u
        WHERE LOWER(TRIM(user_email))=%s AND NOT EXISTS
        (SELECT 1 FROM quit q WHERE q.user_user_id=u.user_id)"""
    args = [email]
    if user_id is not None:
        sql += ' AND user_id=%s'; args.append(user_id)
    if locked: sql += ' FOR UPDATE'
    with db.cursor() as cursor:
        cursor.execute(sql, tuple(args))
        return cursor.fetchall()


def request_code(db, request, client_ip):
    if request.purpose == 'reset_password' and not request.user_id:
        raise HTTPException(422, '비밀번호를 재설정할 아이디를 입력해주세요.')
    recovery_mail_service.mail_settings()
    email = request.email.strip().lower()
    now = time.monotonic()
    email_key, ip_key = _digest('email:' + email), _digest('ip:' + client_ip)
    with _lock:
        for key in list(_challenges):
            if _challenges[key]['expires'] <= now: del _challenges[key]
        for key in list(_rates):
            _rates[key] = [t for t in _rates[key] if now-t < 3600]
            if not _rates[key]: del _rates[key]
        email_times, ip_times = _rates.get(email_key, []), _rates.get(ip_key, [])
        if (email_times and now-email_times[-1] < 60) or len(email_times) >= 5 or len(ip_times) >= 20:
            raise HTTPException(429, '인증번호 요청이 많습니다. 잠시 후 다시 시도해주세요.', headers={'Retry-After': '60'})
        if len(_rates) >= 10000 or len(_challenges) >= 10000:
            raise HTTPException(503, '잠시 후 다시 시도해주세요.')
        _rates[email_key] = [*email_times, now]
        _rates[ip_key] = [*ip_times, now]
    rows = _accounts(db, email, request.user_id if request.purpose == 'reset_password' else None)
    code, challenge_id = f'{secrets.randbelow(1000000):06d}', uuid4().hex
    entry = dict(email=email, purpose=request.purpose, bindings={r['user_id']: _binding(r) for r in rows},
                 code_hash=_digest(challenge_id + ':' + code), expires=now+300, attempts=0, ready=False)
    with _lock: _challenges[challenge_id] = entry
    try:
        if rows: recovery_mail_service.send_code(email, code)
    except Exception:
        with _lock: _challenges.pop(challenge_id, None)
        raise
    with _lock:
        entry['ready'] = True
    return {'challenge_id': challenge_id}


def complete(db, request):
    # Lock prevents simultaneous guesses/reuse and serializes completion within the supported single worker.
    with _lock:
        entry = _challenges.get(request.challenge_id)
        if entry is None or not entry['ready'] or entry['expires'] <= time.monotonic() or entry['attempts'] >= 5:
            raise HTTPException(400, '인증번호가 만료되었거나 사용할 수 없습니다. 다시 요청해주세요.')
        if entry['purpose'] == 'reset_password' and request.new_password is None:
            raise HTTPException(422, '새 비밀번호를 입력해주세요.')
        entry['attempts'] += 1
        if not hmac.compare_digest(entry['code_hash'], _digest(request.challenge_id + ':' + request.code)):
            raise HTTPException(400, '인증번호가 올바르지 않습니다.')
        try:
            db.begin()
            rows = _accounts(db, entry['email'], locked=True)
            eligible = [r for r in rows if r['user_id'] in entry['bindings'] and hmac.compare_digest(entry['bindings'][r['user_id']], _binding(r))]
            if not eligible:
                raise HTTPException(400, '가입 정보를 확인할 수 없습니다. 다시 요청해주세요.')
            if entry['purpose'] == 'reset_password':
                if len(eligible) != 1: raise HTTPException(400, '가입 정보를 확인해주세요.')
                with db.cursor() as cursor:
                    cursor.execute('UPDATE `user` SET user_password=%s WHERE user_id=%s',
                                   (hash_password(request.new_password), eligible[0]['user_id']))
                result = {'message': '비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요.'}
            else:
                result = {'user_ids': sorted(r['user_id'] for r in eligible), 'message': '가입한 아이디를 확인해주세요.'}
            db.commit()
        except Exception:
            db.rollback()
            raise
        _challenges.pop(request.challenge_id, None)
        return result
