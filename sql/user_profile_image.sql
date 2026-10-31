-- Apply once to databases without user_profile_image. Existing users keep NULL.
ALTER TABLE `user` ADD COLUMN `user_profile_image` VARCHAR(1000) NULL DEFAULT NULL;
