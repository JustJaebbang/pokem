-- 날짜 컬럼은 프로젝트 정책에 따라 DATETIME 대신 VARCHAR(45)를 사용한다.
-- 실제 이미지 데이터는 이 테이블에 저장하고 sell_product에는 조회 URL만 저장한다.
CREATE TABLE IF NOT EXISTS product_image (
    product_image_id VARCHAR(32) PRIMARY KEY,
    product_image_extension VARCHAR(5) NOT NULL,
    product_image_mime VARCHAR(50) NOT NULL,
    product_image_data MEDIUMBLOB NOT NULL,
    product_image_size INT UNSIGNED NOT NULL,
    product_image_created_at VARCHAR(45) NOT NULL
);
