-- 반환 날짜/상태를 포함한 이전 return 구현에 한 번만 적용합니다.
-- 반환 식별자, 검수·사용자·매니저 연결과 delivery 외래키는 유지합니다.
-- 삭제되는 컬럼의 값은 보존되지 않습니다. 배송 일자와 상태는 delivery에서 관리합니다.
ALTER TABLE `return`
    DROP CHECK `chk_return_status`,
    DROP COLUMN `return_date`,
    DROP COLUMN `return_status`,
    DROP COLUMN `return_completed_at`;
