-- 날짜 컬럼은 프로젝트 정책에 따라 VARCHAR(45)를 유지한다.
CREATE TABLE IF NOT EXISTS director_settings (
    settings_id TINYINT PRIMARY KEY,
    low_stock_threshold INT NOT NULL DEFAULT 10,
    delivery_delay_days INT NOT NULL DEFAULT 3,
    inspection_unit_price INT NOT NULL DEFAULT 10000,
    updated_at VARCHAR(45) NOT NULL,
    director_director_id VARCHAR(45) NULL,
    CONSTRAINT fk_director_settings_director
        FOREIGN KEY (director_director_id) REFERENCES director(director_id)
);

INSERT INTO director_settings (
    settings_id, low_stock_threshold, delivery_delay_days,
    inspection_unit_price, updated_at, director_director_id
) VALUES (1, 10, 3, 10000, '2026-11-01 00:00:00', NULL)
ON DUPLICATE KEY UPDATE settings_id = settings_id;

ALTER TABLE manager
    ADD COLUMN manager_active TINYINT(1) NOT NULL DEFAULT 1,
    ADD COLUMN manager_updated_at VARCHAR(45) NULL;
