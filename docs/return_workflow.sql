-- 신규 적용용입니다. 이전 반환 기능을 이미 적용했다면 return_delivery_fields.sql만 실행합니다.
-- 기존 return 테이블이 비어 있는 경우에만 적용합니다.
-- 데이터가 있다면 intention_code/판매상품을 검수 물품으로 매핑한 뒤 별도 이관해야 합니다.
-- MySQL DDL은 암묵적으로 커밋됩니다. 적용 후 반복 실행하지 않습니다.
-- return_no의 타입/키와 delivery의 기존 외래키는 변경하지 않습니다.
ALTER TABLE `return`
    DROP FOREIGN KEY `fk_return_sell_product`,
    DROP COLUMN `sell_product_sell_product_code`,
    DROP COLUMN `intention_code`,
    ADD COLUMN `inspect_inspect_code` VARCHAR(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
    DROP COLUMN `return_status`,
    DROP COLUMN `return_date`,
    MODIFY COLUMN `manager_manager_id` VARCHAR(45) NULL,
    ADD CONSTRAINT `uq_return_inspect` UNIQUE (`inspect_inspect_code`),
    ADD CONSTRAINT `fk_return_inspect` FOREIGN KEY (`inspect_inspect_code`)
        REFERENCES `inspect` (`inspect_code`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- 기존에 반환을 선택한 검수 물품도 접수합니다.
INSERT INTO `return` (return_no, inspect_inspect_code, user_user_id)
SELECT CONCAT('RET_', REPLACE(UUID(), '-', '')), i.inspect_code, ir.user_user_id
FROM inspect i
JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
WHERE i.inspect_status = '검수완료' AND i.inspect_user_choice = '반환'
  AND NOT EXISTS (SELECT 1 FROM `return` r WHERE r.inspect_inspect_code = i.inspect_code);
