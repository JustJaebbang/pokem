-- 배송 단계별 처리자와 메모를 보존한다. 날짜는 프로젝트 정책대로 VARCHAR를 사용한다.
CREATE TABLE IF NOT EXISTS delivery_status_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    delivery_delivery_no VARCHAR(64) NOT NULL,
    previous_status VARCHAR(45) NULL,
    changed_status VARCHAR(45) NOT NULL,
    manager_manager_id VARCHAR(45) NOT NULL,
    changed_at VARCHAR(45) NOT NULL,
    memo VARCHAR(500) NULL,
    CONSTRAINT fk_delivery_status_history_delivery
        FOREIGN KEY (delivery_delivery_no) REFERENCES delivery(delivery_no),
    CONSTRAINT fk_delivery_status_history_manager
        FOREIGN KEY (manager_manager_id) REFERENCES manager(manager_id),
    INDEX ix_delivery_status_history_delivery (
        delivery_delivery_no, history_id
    )
);
