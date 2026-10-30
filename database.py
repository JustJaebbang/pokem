import os
from pathlib import Path

import pymysql
from pymysql.cursors import DictCursor
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env")


def get_connection_options():
    return dict(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
        connect_timeout=5,
    )


def get_connection():
    return pymysql.connect(**get_connection_options())


def get_db():
    connection = get_connection()

    try:
        yield connection
    finally:
        connection.close()