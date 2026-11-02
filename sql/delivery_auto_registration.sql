-- 자동 생성 후 담당자가 배송업체를 지정한다. 기존 외래키·고유키는 유지한다.
ALTER TABLE delivery MODIFY COLUMN delivery_company_delivery_company_code VARCHAR(45) NULL;
