-- 반환 진행 상태를 배송 흐름과 함께 표시하기 위한 컬럼입니다.
ALTER TABLE `return`
    ADD COLUMN return_status VARCHAR(45) NOT NULL DEFAULT '반환접수';

-- 기존 담당자 배정 건은 바로 배송을 등록할 수 있는 상태로 보정합니다.
UPDATE `return`
SET return_status = '배송대기'
WHERE manager_manager_id IS NOT NULL;
