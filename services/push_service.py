import hashlib
import os
from uuid import uuid4
from fastapi import HTTPException


def enabled():
    return os.getenv('PUSH_ENABLED', 'false').lower() == 'true'


def register_device(db, installation_id, user_id, fid):
    if not enabled(): raise HTTPException(503, '푸시 알림 설정이 아직 완료되지 않았습니다.')
    digest = hashlib.sha256(fid.encode()).hexdigest()
    try:
        db.begin()
        with db.cursor() as c:
            # Serialize reassignment of a device; no fid is returned or logged.
            c.execute('SELECT binding_id,user_id FROM push_device WHERE installation_id=%s FOR UPDATE', (installation_id,))
            old = c.fetchone()
            binding = old['binding_id'] if old and old['user_id'] == user_id else uuid4().hex
            # FCM can preserve a fid across app installation identifiers.
            c.execute('DELETE FROM push_device WHERE fid_hash=%s AND installation_id<>%s', (digest, installation_id))
            c.execute("""INSERT INTO push_device(installation_id,user_id,binding_id,fid,fid_hash,updated_at)
                VALUES(%s,%s,%s,%s,%s,UTC_TIMESTAMP(6))
                ON DUPLICATE KEY UPDATE user_id=VALUES(user_id),binding_id=VALUES(binding_id),
                  fid=VALUES(fid),fid_hash=VALUES(fid_hash),updated_at=VALUES(updated_at)""",
                (installation_id,user_id,binding,fid,digest))
        db.commit()
    except Exception:
        db.rollback(); raise
    return {'registered':True}


def unregister_device(db, installation_id, user_id):
    if not enabled(): return {'registered':False}
    try:
        with db.cursor() as c:
            c.execute('DELETE FROM push_device WHERE installation_id=%s AND user_id=%s', (installation_id,user_id))
        db.commit()
    except Exception:
        db.rollback(); raise
    return {'registered':False}


def enqueue_inspection(cursor, item):
    if not enabled(): return
    # Same transaction as the inspection transition. An event is queued for each current device.
    cursor.execute("""INSERT INTO push_outbox
        (event_key,installation_id,binding_id,user_id,target_code,next_at,created_at)
        SELECT %s,installation_id,binding_id,user_id,%s,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6)
        FROM push_device WHERE user_id=%s
        ON DUPLICATE KEY UPDATE event_key=VALUES(event_key)""",
        ('inspection_complete:'+item.inspect_code,item.inspect_requested_no,item.user_user_id))
