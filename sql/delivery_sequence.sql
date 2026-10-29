-- Apply delivery_purchase_item.sql first for the purchase-based schema.
CREATE TABLE IF NOT EXISTS delivery_sequence (
    delivery_date DATE NOT NULL PRIMARY KEY,
    last_seq INT UNSIGNED NOT NULL
) ENGINE=InnoDB;

-- 기존 번호 중 YYYYMMDD + 6자리 순번 형식의 최댓값으로 일별 순번을 초기화한다.
-- 이미 저장된 순번보다 작은 값으로 되돌리지 않는다.
INSERT INTO delivery_sequence (delivery_date, last_seq)
SELECT STR_TO_DATE(LEFT(delivery_no, 8), '%Y%m%d'),
       MAX(CAST(RIGHT(delivery_no, 6) AS UNSIGNED))
FROM delivery
WHERE delivery_no REGEXP '^[0-9]{14}$'
GROUP BY LEFT(delivery_no, 8)
ON DUPLICATE KEY UPDATE last_seq = GREATEST(last_seq, VALUES(last_seq));
