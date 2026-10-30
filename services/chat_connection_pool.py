"""채팅 작업 사이에 DB 연결을 반환하고 재사용한다."""
import atexit
import os
from threading import Lock

import pymysql
from dbutils.pooled_db import PooledDB

from database import get_connection_options

_pool = None
_pool_lock = Lock()


def get_chat_connection():
    global _pool
    with _pool_lock:
        if _pool is None:
            size = int(os.getenv("CHAT_DB_POOL_SIZE", "8"))
            if size < 1:
                raise ValueError("CHAT_DB_POOL_SIZE must be positive")
            _pool = PooledDB(
                creator=pymysql, mincached=0, maxcached=size,
                maxconnections=size, maxshared=0, blocking=True,
                reset=True, ping=1, **get_connection_options(),
            )
        pool = _pool
    return pool.connection(shareable=False)


def close_chat_pool():
    global _pool
    with _pool_lock:
        if _pool is not None:
            _pool.close()
            _pool = None


atexit.register(close_chat_pool)
