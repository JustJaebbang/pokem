from fastapi import HTTPException
from datetime import datetime, timedelta, timezone

from schemas.auth import LoginRequest
from pymysql.err import IntegrityError

from security import hash_password, verify_password

from schemas.user import UserCreate, UserResponse, UserLoginResponse, UserUpdate, UserQuitRequest, UserQuitResponse
from schemas.auth import LoginRequest


# 저장된 비밀번호 해시를 검증합니다. 토큰 발급은 다음 단계에서 구현합니다.
def login_user(db, login: LoginRequest) -> UserLoginResponse:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT user_id, user_password, user_nickname, user_name,
                   user_phone, user_email, user_address, user_money
            FROM `user`
            WHERE user_id = %s
              AND NOT EXISTS (SELECT 1 FROM `quit` q WHERE q.user_user_id = `user`.user_id)
            """,
            (login.login_id,),
        )
        user = cursor.fetchone()
    if user is None or not verify_password(login.password, user["user_password"]):
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    # 응답 스키마에 비밀번호 필드가 없으므로 계정 응답에서 제외됩니다.
    return UserLoginResponse(account=UserResponse(**user))

# user 생성하기(회원가입)
def create_user(db, user: UserCreate) -> UserResponse:
    try:
        password_hash = hash_password(user.user_password)
        sql = """
              insert into user
              (user_id,user_password,user_nickname,user_name,user_phone,user_email,user_address,user_money) 
              values 
              (%s,%s,%s,%s,%s,%s,%s,%s)
              """
        with db.cursor() as cursor:
            cursor.execute(sql,
                            (
                                user.user_id,
                                password_hash,
                                user.user_nickname,
                                user.user_name,
                                user.user_phone,
                                user.user_email,
                                user.user_address,
                                0
                            )
                        )

        db.commit()
        return get_user_id(db, user.user_id)
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 사용 중인 아이디입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise

# 모든 user 정보 가져오기
def get_user(db) -> list[UserResponse]: #UserResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                user_id, user_nickname, user_name,
                user_phone, user_email, user_address, user_money
            FROM user
            """,
        )
        rows = cursor.fetchall()

    return [UserResponse(**row) for row in rows]


# user_id에 해당하는 user 정보 가져오기
def get_user_id(db, user_id: str) -> UserResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                user_id, user_nickname, user_name,
                user_phone, user_email, user_address, user_money
            FROM user
            WHERE user_id = %s
              AND NOT EXISTS (SELECT 1 FROM `quit` q WHERE q.user_user_id = user.user_id)
            """,
            (user_id,),
        )
        row = cursor.fetchone()

    return UserResponse(**row) if row else None


# user_id에 해당하는 user 정보 변경
def put_user_id(db, user: UserUpdate, user_id: str) -> UserResponse | None:
    try:
        with db.cursor() as cursor:
            cursor.execute(
                """
                UPDATE `user`
                SET user_phone = %s,
                    user_email = %s,
                    user_address = %s
                WHERE user_id = %s
                """,
                (
                    user.user_phone,
                    user.user_email,
                    user.user_address,
                    user_id,
                ),
            )

        db.commit()

    except Exception:
        db.rollback()
        raise

    return get_user_id(db, user_id)


# user 및 거래 이력은 보존하고 quit 기록으로 탈퇴 여부를 판단한다.
def delete_user_id(db, quit: UserQuitRequest, user_id: str) -> UserQuitResponse | None:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_id, user_money 
                FROM `user` 
                WHERE user_id = %s FOR UPDATE
                """,
                (user_id,),
            )
            account = cursor.fetchone()
            if account is None:
                db.rollback()
                return None

            if account["user_money"] != 0:
                raise HTTPException(status_code=409, detail="포켐머니 잔액을 정리한 후 탈퇴해주세요.")

            cursor.execute(
                "SELECT user_user_id FROM `quit` WHERE user_user_id = %s FOR UPDATE",
                (user_id,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="이미 탈퇴한 계정입니다.")

            quit_date = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
            result = UserQuitResponse(
                message="회원 탈퇴가 완료되었습니다.",
                user_id=user_id,
                quit_date=quit_date,
                quit_reason=quit.quit_reason,
            )
            cursor.execute(
                """
                INSERT INTO `quit` (user_user_id, quit_date, quit_reason)
                VALUES (%s, %s, %s)
                """,
                (user_id, quit_date, quit.quit_reason),
            )
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(
                status_code=409,
                detail="이미 해당 아이디의 탈퇴 기록이 존재합니다.",
            ) from exc
        raise
    except Exception:
        db.rollback()
        raise

    return result
