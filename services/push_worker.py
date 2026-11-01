import asyncio
import logging
from uuid import uuid4
from database import get_connection
from services.push_service import enabled

logger=logging.getLogger(__name__)


def send(fid, data):
    import firebase_admin
    from firebase_admin import messaging
    try: app=firebase_admin.get_app('pokem-push')
    except ValueError:
        app=firebase_admin.initialize_app(options={'httpTimeout':5},name='pokem-push')
    return messaging.send(messaging.Message(
        fid=fid, data=data,
        notification=messaging.Notification(title='검수가 완료되었습니다',body='앱에서 검수 결과를 확인해주세요.'),
        android=messaging.AndroidConfig(priority='high',notification=messaging.AndroidNotification(
            channel_id='inspection_updates',tag=data['event_id'],icon='ic_stat_pokem')),
    ),app=app)


def process_one(db, sender=send):
    lease=uuid4().hex
    try:
        db.begin()
        with db.cursor() as c:
            c.execute("""UPDATE push_outbox SET status='failed',lease_id=NULL,lease_until=NULL
                WHERE status='sending' AND attempts>=5 AND lease_until<UTC_TIMESTAMP(6)""")
            c.execute("""SELECT * FROM push_outbox WHERE attempts<5 AND
              ((status='pending' AND next_at<=UTC_TIMESTAMP(6)) OR
               (status='sending' AND lease_until<UTC_TIMESTAMP(6)))
              ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED""")
            event=c.fetchone()
            if not event:
                db.commit(); return False
            c.execute("""UPDATE push_outbox SET status='sending',attempts=attempts+1,
                lease_id=%s,lease_until=UTC_TIMESTAMP(6)+INTERVAL 60 SECOND WHERE id=%s""",(lease,event['id']))
            c.execute("""SELECT d.fid,d.fid_hash FROM push_device d JOIN `user` u ON u.user_id=d.user_id
                WHERE d.installation_id=%s AND d.binding_id=%s AND d.user_id=%s
                AND NOT EXISTS (SELECT 1 FROM quit q WHERE q.user_user_id=d.user_id)""",
                (event['installation_id'],event['binding_id'],event['user_id']))
            device=c.fetchone()
        db.commit()
    except Exception:
        db.rollback();raise
    status='skipped'
    invalid=False
    if device:
        try:
            sender(device['fid'],{'target_type':'inspection_results','target_code':event['target_code'],
                'owner_id':event['user_id'],'event_id':event['event_key']})
            status='sent'
        except Exception as exc:
            from firebase_admin.messaging import UnregisteredError, SenderIdMismatchError
            invalid=isinstance(exc,(UnregisteredError,SenderIdMismatchError))
            status='failed' if invalid or event['attempts']+1>=5 else 'pending'
            # SDK error text may contain registration credentials. Never log it.
            logger.warning('FCM 발송 실패: %s',type(exc).__name__)
    try:
        with db.cursor() as c:
            if invalid:
                c.execute('DELETE FROM push_device WHERE installation_id=%s AND fid_hash=%s',
                          (event['installation_id'],device['fid_hash']))
            c.execute("""UPDATE push_outbox SET status=%s,lease_id=NULL,lease_until=NULL,
                next_at=UTC_TIMESTAMP(6)+INTERVAL %s SECOND WHERE id=%s AND lease_id=%s""",
                (status,min(3600,30*2**event['attempts']),event['id'],lease))
        db.commit()
    except Exception:
        db.rollback();raise
    return True


def run_once():
    db=get_connection()
    try:
        for _ in range(10):
            if not process_one(db):break
    finally:db.close()


async def push_worker(stop):
    if not enabled(): return
    while not stop.is_set():
        try:await asyncio.to_thread(run_once)
        except Exception as exc:logger.warning('푸시 작업 실패: %s',type(exc).__name__)
        try:await asyncio.wait_for(stop.wait(),timeout=5)
        except asyncio.TimeoutError:pass
