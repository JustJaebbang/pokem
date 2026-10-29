-- API 쓰기를 중단한 상태에서 순서대로 실행한다. DDL은 자동 커밋된다.
-- 현재 DB에서 확인한 외래키와 NOT NULL 조건을 유지한다.
USE pokem_aiven;

ALTER TABLE deposit_refund DROP FOREIGN KEY fk_deposit_refund_pay1;
ALTER TABLE receipt DROP FOREIGN KEY fk_receipt_pay1;

ALTER TABLE pay
    MODIFY COLUMN pay_no VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
ALTER TABLE deposit_refund
    MODIFY COLUMN pay_pay_no VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;
ALTER TABLE receipt
    MODIFY COLUMN pay_pay_no VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE deposit_refund
    ADD CONSTRAINT fk_deposit_refund_pay1 FOREIGN KEY (pay_pay_no) REFERENCES pay (pay_no);
ALTER TABLE receipt
    ADD CONSTRAINT fk_receipt_pay1 FOREIGN KEY (pay_pay_no) REFERENCES pay (pay_no);
