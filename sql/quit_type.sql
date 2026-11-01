-- Director가 탈퇴 현황을 분류해서 확인할 수 있도록 탈퇴 종류를 저장한다.
-- 기존 탈퇴 기록과 구버전 앱 요청은 '기타'로 분류한다.
ALTER TABLE `quit`
    ADD COLUMN `quit_type` VARCHAR(45) NOT NULL DEFAULT '기타'
    AFTER `quit_date`;
