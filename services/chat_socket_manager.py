import asyncio
import logging
from contextlib import asynccontextmanager
from dataclasses import dataclass, field

from fastapi import HTTPException
from starlette.concurrency import run_in_threadpool

logger = logging.getLogger(__name__)


@dataclass(eq=False)
class ChatPeer:
    websocket: object
    room_id: str
    token: str
    backend: object
    send_lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def send(self, payload):
        async with self.send_lock:
            await asyncio.wait_for(self.websocket.send_json(payload), timeout=5)

    async def close(self, code=1008):
        try:
            async with self.send_lock:
                await asyncio.wait_for(self.websocket.close(code=code), timeout=5)
        except Exception:
            pass


class ChatSocketManager:
    # 이 전달 목록은 한 프로세스 안에서만 공유됩니다.
    def __init__(self):
        self.rooms = {}
        self.locks = {}

    def add(self, peer):
        self.rooms.setdefault(peer.room_id, set()).add(peer)

    def remove(self, peer):
        peers = self.rooms.get(peer.room_id)
        if peers is not None:
            peers.discard(peer)
            if not peers:
                self.rooms.pop(peer.room_id, None)

    @asynccontextmanager
    async def serialize(self, room_id):
        # HTTP/WS 메시지의 저장과 방송 순서를 방별로 일치시킵니다.
        lock, count = self.locks.get(room_id, (asyncio.Lock(), 0))
        self.locks[room_id] = (lock, count + 1)
        try:
            async with lock:
                yield
        finally:
            current_lock, current_count = self.locks[room_id]
            if current_count == 1:
                self.locks.pop(room_id)
            else:
                self.locks[room_id] = (current_lock, current_count - 1)

    async def _deliver(self, peer, payload):
        try:
            # 수신 전에도 만료·탈퇴·참여 권한을 확인합니다.
            await run_in_threadpool(peer.backend.authorize, peer.room_id, peer.token)
            await peer.send(payload)
        except HTTPException:
            self.remove(peer)
            await peer.close(1008)
        except Exception:
            logger.exception("WebSocket delivery failed")
            self.remove(peer)
            await peer.close(1011)

    async def publish(self, room_id, message):
        payload = {"type": "message", "data": message.model_dump(mode="json")}
        peers = tuple(self.rooms.get(room_id, ()))
        await asyncio.gather(*(self._deliver(peer, payload) for peer in peers))


chat_socket_manager = ChatSocketManager()
