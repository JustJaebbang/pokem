-- 결제번호(최대 64자) + 반환일자(8자, YYYYMMDD)를 저장한다. 컬럼은 85자를 유지한다.
-- 기존 환급 번호는 유지한다. 이 변경은 앞선 번호 타입 변경 이후 적용한다.
ALTER TABLE pokem_aiven.deposit_refund
MODIFY COLUMN deposit_refund_no VARCHAR(85)
CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
