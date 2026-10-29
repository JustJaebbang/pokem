-- 기존 delivery에 데이터가 없는 상태에서 적용하는 구조 변경이다.
-- 데이터가 있다면 구매 건을 확인·매핑하는 별도 이전 작업이 필요하다.
-- 구매번호 컬럼의 타입/문자셋/정렬은 purchase_item.purchase_item_code와 같아야 한다.
ALTER TABLE delivery
    DROP FOREIGN KEY fk_delivery_user1,
    DROP FOREIGN KEY fk_delivery_sell_product,
    DROP COLUMN user_user_id,
    DROP COLUMN sell_product_sell_product_code,
    ADD COLUMN purchase_item_purchase_item_code VARCHAR(45)
        CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
    ADD UNIQUE KEY uq_delivery_purchase_item (purchase_item_purchase_item_code),
    ADD CONSTRAINT fk_delivery_purchase_item
        FOREIGN KEY (purchase_item_purchase_item_code)
        REFERENCES purchase_item (purchase_item_code)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

-- 배송번호: 한국 날짜 YYYYMMDD + 일별 순번 6자리.
CREATE TABLE IF NOT EXISTS delivery_sequence (
    delivery_date DATE NOT NULL PRIMARY KEY,
    last_seq INT UNSIGNED NOT NULL
) ENGINE=InnoDB;
