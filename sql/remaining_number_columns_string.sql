-- Convert remaining numeric _no columns to VARCHAR(64); retain existing string columns.
-- Removes AUTO_INCREMENT from review_no; applications must generate future review numbers.
-- Run once with writes stopped. MySQL DDL commits automatically.
USE pokem_aiven;

ALTER TABLE `order` DROP FOREIGN KEY `fk_order_proposal1`;

ALTER TABLE `receive` DROP FOREIGN KEY `fk_receive_order1`;

ALTER TABLE `case` MODIFY COLUMN `case_serial_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL;

ALTER TABLE `delivery` MODIFY COLUMN `delivery_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `deposit_refund` MODIFY COLUMN `deposit_refund_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `order` MODIFY COLUMN `order_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `order` MODIFY COLUMN `proposal_proposal_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `proposal` MODIFY COLUMN `proposal_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `receipt` MODIFY COLUMN `receipt_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `receive` MODIFY COLUMN `receive_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `receive` MODIFY COLUMN `order_order_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `return` MODIFY COLUMN `return_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `review` MODIFY COLUMN `review_no` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

ALTER TABLE `order` ADD CONSTRAINT `fk_order_proposal1` FOREIGN KEY (`proposal_proposal_no`) REFERENCES `proposal` (`proposal_no`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `receive` ADD CONSTRAINT `fk_receive_order1` FOREIGN KEY (`order_order_no`) REFERENCES `order` (`order_no`) ON DELETE NO ACTION ON UPDATE NO ACTION;
