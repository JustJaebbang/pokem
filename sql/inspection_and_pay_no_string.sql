-- 번호를 문자열로 변경한다. 기존 데이터와 외래키 규칙을 유지한다.
-- DDL은 자동 커밋되므로 API 쓰기를 중단한 상태에서 순서대로 실행한다.
USE pokem_aiven;

ALTER TABLE pay DROP FOREIGN KEY fk_pay_inspection_request1;
ALTER TABLE inspect DROP FOREIGN KEY fk_inspect_inspection_request1;
ALTER TABLE receipt DROP FOREIGN KEY fk_receipt_pay1;
ALTER TABLE deposit_refund DROP FOREIGN KEY fk_deposit_refund_pay1;

ALTER TABLE inspection_request MODIFY COLUMN inspection_request_no VARCHAR(14) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
ALTER TABLE pay
    MODIFY COLUMN pay_no VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
    MODIFY COLUMN inspection_request_inspection_request_no VARCHAR(14) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
ALTER TABLE inspect MODIFY COLUMN inspection_request_inspection_request_no VARCHAR(14) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
ALTER TABLE receipt MODIFY COLUMN pay_pay_no VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
ALTER TABLE deposit_refund MODIFY COLUMN pay_pay_no VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE pay ADD CONSTRAINT fk_pay_inspection_request1 FOREIGN KEY (inspection_request_inspection_request_no) REFERENCES inspection_request (inspection_request_no);
ALTER TABLE inspect ADD CONSTRAINT fk_inspect_inspection_request1 FOREIGN KEY (inspection_request_inspection_request_no) REFERENCES inspection_request (inspection_request_no);
ALTER TABLE receipt ADD CONSTRAINT fk_receipt_pay1 FOREIGN KEY (pay_pay_no) REFERENCES pay (pay_no);
ALTER TABLE deposit_refund ADD CONSTRAINT fk_deposit_refund_pay1 FOREIGN KEY (pay_pay_no) REFERENCES pay (pay_no);
