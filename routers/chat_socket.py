import asyncio
import json
import logging
import time

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import ValidationError
from starlette.concurrency import run_in_threadpool

from schemas.chat import ChatCreate
from services.chat_socket_backend import get_chat_socket_backend
from services.chat_socket_manager import ChatPeer, chat_socket_manager

router = APIRouter()
logger = logging.getLogger(__name__)


async def _text(websocket):
    text = await websocket.receive_text()
    if len(text.encode("utf-8")) > 4096:
        raise HTTPException(status_code=413, detail="메시지 요청이 너무 큽니다.")
    return text


@router.websocket("/chat_room/{room_id}/ws")
async def chat_websocket(websocket: WebSocket, room_id: str, backend=Depends(get_chat_socket_backend)):
    peer = None
    await websocket.accept()
    try:
        authorization = websocket.headers.get("authorization", "")
        if authorization:
            scheme, _, token = authorization.partition(" ")
            if scheme.lower() != "bearer" or not token:
                raise HTTPException(status_code=401, detail="Bearer 토큰이 필요합니다.")
        else:
            # 브라우저 WebSocket API는 임의 Authorization 헤더를 지정할 수 없습니다.
            # URL에 토큰을 노출하지 않도록 첫 프레임으로 인증합니다.
            raw = await asyncio.wait_for(_text(websocket), timeout=10)
            try:
                auth = json.loads(raw)
            except ValueError as exc:
                raise HTTPException(status_code=401, detail="첫 메시지로 인증 정보를 보내주세요.") from exc
            if not isinstance(auth, dict) or auth.get("type") != "auth" or not isinstance(auth.get("access_token"), str):
                raise HTTPException(status_code=401, detail="첫 메시지로 인증 정보를 보내주세요.")
            token = auth["access_token"]
        claims = await run_in_threadpool(backend.authorize, room_id, token)
        peer = ChatPeer(websocket, room_id, token, backend)
        # 구독과 ready 전송을 묶어 연결 직후 메시지가 누락되거나 ready를 앞서지 않게 합니다.
        async with peer.send_lock:
            chat_socket_manager.add(peer)
            await websocket.send_json({"type": "ready", "room_id": room_id, "user_id": claims["sub"]})
        while True:
            remaining = claims["exp"] - time.time()
            if remaining <= 0:
                raise HTTPException(status_code=401, detail="인증 토큰이 만료되었습니다.")
            try:
                text = await asyncio.wait_for(_text(websocket), timeout=min(30, remaining))
            except asyncio.TimeoutError:
                claims = await run_in_threadpool(backend.authorize, room_id, token)
                continue
            # 각 전송 때도 만료 및 DB 계정을 다시 확인합니다.
            claims = await run_in_threadpool(backend.authorize, room_id, token)
            try:
                chat = ChatCreate.model_validate_json(text)
            except ValidationError as exc:
                await peer.send({"type": "error", "status": 422, "detail": "메시지 형식이 올바르지 않습니다.",
                                 "errors": exc.errors(include_input=False, include_context=False)})
                continue
            try:
                async with chat_socket_manager.serialize(room_id):
                    saved = await run_in_threadpool(backend.save, room_id, token, chat)
                    await chat_socket_manager.publish(room_id, saved)
            except HTTPException as exc:
                if exc.status_code in (401, 403, 404):
                    raise
                await peer.send({"type": "error", "status": exc.status_code, "detail": exc.detail})
            except Exception:
                # 저장 실패 시 방송하지 않으며 내부 DB 오류는 클라이언트에 노출하지 않습니다.
                logger.error("WebSocket chat save failed")
                await peer.send({"type": "error", "status": 500, "detail": "메시지 저장에 실패했습니다."})
    except WebSocketDisconnect:
        pass
    except (HTTPException, asyncio.TimeoutError) as exc:
        status = exc.status_code if isinstance(exc, HTTPException) else 401
        detail = exc.detail if isinstance(exc, HTTPException) else "인증 시간이 초과되었습니다."
        try:
            payload = {"type": "error", "status": status, "detail": detail}
            if peer:
                await peer.send(payload)
            else:
                await websocket.send_json(payload)
        except (RuntimeError, OSError):
            pass
        if peer:
            await peer.close(1009 if status == 413 else 1008)
        else:
            await websocket.close(code=1009 if status == 413 else 1008)
    except (KeyError, UnicodeError):
        await websocket.close(code=1003)
    except Exception:
        logger.error("WebSocket chat connection failed")
        if peer:
            await peer.close(1011)
        else:
            await websocket.close(code=1011)
    finally:
        if peer:
            chat_socket_manager.remove(peer)
