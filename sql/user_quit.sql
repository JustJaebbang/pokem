-- 회원 탈퇴 API 사용 전 적용해야 하는 스키마 변경입니다.
-- 탈퇴 기록은 사용자 삭제 후에도 보존되므로 user에 대한 외래 키를 제거합니다.
-- 다른 테이블의 외래 키는 변경하지 않습니다.
ALTER TABLE `quit` DROP FOREIGN KEY `fk_quit_user1`;
