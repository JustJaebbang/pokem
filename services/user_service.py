from fastapi import HTTPException

from schemas.auth import LoginRequest

from schemas.user import UserCreate, UserResponse, UserLoginResponse


# 현재 DB에 저장된 평문 비밀번호와 비교합니다. 로그인 상태는 생성하지 않습니다.
def login_user(db, login: LoginRequest) -> UserLoginResponse:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT user_id, user_password, user_nickname, user_name,
                   user_phone, user_email, user_address, user_money
            FROM `user` WHERE user_id = %s
            """,
            (login.login_id,),
        )
        user = cursor.fetchone()
    if user is None or user["user_password"] != login.password:
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    # 응답 스키마에 비밀번호 필드가 없으므로 계정 응답에서 제외됩니다.
    return UserLoginResponse(account=UserResponse(**user))

# user 생성하기(회원가입)
def create_user(db, user: UserCreate) -> UserResponse:
    try:
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
                                user.user_password,
                                user.user_nickname,
                                user.user_name,
                                user.user_phone,
                                user.user_email,
                                user.user_address,
                                user.user_money
                            )
                        )

        db.commit()
        return get_user_id(db, user.user_id)
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
            """,
            (user_id),
        )
        row = cursor.fetchone()

    return UserResponse(**row) if row else None

