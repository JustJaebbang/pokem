from fastapi import APIRouter, Depends, Query, Response

from database import get_db
from dependencies import get_current_user
from schemas.chat_room import ChatRoomCreate, ChatRoomResponse
from schemas.chat import ChatCreate, ChatResponse
from services import chat_room_service, chat_service
from starlette.concurrency import run_in_threadpool
from services.chat_socket_manager import chat_socket_manager

router = APIRouter(prefix="/chat_room", tags=["chat_room"])


@router.post("", response_model=ChatRoomResponse, status_code=201)
def create_chat_room(request: ChatRoomCreate, response: Response, db=Depends(get_db), user=Depends(get_current_user)):
    room, created = chat_room_service.create_chat_room(db, request.sell_product_sell_product_code, user.user_id)
    if not created:
        response.status_code = 200
    return room


@router.get("", response_model=list[ChatRoomResponse])
def get_chat_room(limit: int = Query(default=50, ge=1, le=100), offset: int = Query(default=0, ge=0), db=Depends(get_db), user=Depends(get_current_user)):
    return chat_room_service.get_chat_room(db, user.user_id, limit, offset)


@router.get("/{room_id}", response_model=ChatRoomResponse)
def get_chat_room_id(room_id: str, db=Depends(get_db), user=Depends(get_current_user)):
    return chat_room_service.get_chat_room_id(db, room_id, user.user_id)


@router.post("/{room_id}/messages", response_model=ChatResponse, status_code=201)
async def create_chat(room_id: str, chat: ChatCreate, db=Depends(get_db), user=Depends(get_current_user)):
    async with chat_socket_manager.serialize(room_id):
        saved = await run_in_threadpool(chat_service.create_chat, db, room_id, chat, user.user_id)
        await chat_socket_manager.publish(room_id, saved)
    return saved


@router.get("/{room_id}/messages", response_model=list[ChatResponse])
def get_chat(room_id: str, after_chat_seq: int = Query(default=0, ge=0), limit: int = Query(default=50, ge=1, le=100), db=Depends(get_db), user=Depends(get_current_user)):
    return chat_service.get_chat(db, room_id, user.user_id, after_chat_seq, limit)
