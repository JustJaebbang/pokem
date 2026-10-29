-- 요청 번호 형식: YYYYMMDD + 6자리 일일 순번 (예: 20261028000001).
-- inspection_request.inspection_request_no는 AUTO_INCREMENT 없는 BIGINT여야 한다.
-- 기존 외래키가 있다면 참조 컬럼도 같은 타입으로 변경해야 한다.
-- 실제 테이블 DDL에 맞춰 번호 컬럼을 변경한 뒤 이 스크립트를 적용한다.
CREATE TABLE IF NOT EXISTS inspection_request_sequence (
    request_date DATE NOT NULL PRIMARY KEY,
    last_seq INT UNSIGNED NOT NULL
) ENGINE=InnoDB;

-- 기존 번호가 위 형식을 사용하는 경우에만, 쓰기 중단 상태에서 초기화한다.
INSERT INTO inspection_request_sequence (request_date, last_seq)
SELECT STR_TO_DATE(LEFT(CAST(inspection_request_no AS CHAR), 8), '%Y%m%d'),
       MAX(MOD(inspection_request_no, 1000000))
FROM inspection_request
WHERE inspection_request_no BETWEEN 10000101000001 AND 99991231999999
GROUP BY LEFT(CAST(inspection_request_no AS CHAR), 8)
ON DUPLICATE KEY UPDATE last_seq = GREATEST(last_seq, VALUES(last_seq));
