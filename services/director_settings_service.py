from datetime import datetime
from zoneinfo import ZoneInfo

from schemas.director import DirectorSettingsResponse, DirectorSettingsUpdate


def get_settings(db, *, for_update: bool = False) -> DirectorSettingsResponse:
    """단일 운영 설정을 조회한다. 날짜는 프로젝트 정책대로 문자열로 저장한다."""
    suffix = " FOR UPDATE" if for_update else ""
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT low_stock_threshold, delivery_delay_days,
                      inspection_unit_price, updated_at, director_director_id
               FROM director_settings WHERE settings_id = 1""" + suffix
        )
        row = cursor.fetchone()
    if row is None:
        raise RuntimeError("Director 운영 설정이 초기화되지 않았습니다.")
    return DirectorSettingsResponse(**row)


def update_settings(
    db,
    request: DirectorSettingsUpdate,
    director_id: str,
) -> DirectorSettingsResponse:
    try:
        db.begin()
        get_settings(db, for_update=True)
        updated_at = datetime.now(ZoneInfo("Asia/Seoul")).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        with db.cursor() as cursor:
            cursor.execute(
                """UPDATE director_settings
                   SET low_stock_threshold = %s,
                       delivery_delay_days = %s,
                       inspection_unit_price = %s,
                       updated_at = %s,
                       director_director_id = %s
                   WHERE settings_id = 1""",
                (
                    request.low_stock_threshold,
                    request.delivery_delay_days,
                    request.inspection_unit_price,
                    updated_at,
                    director_id,
                ),
            )
        result = get_settings(db)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
