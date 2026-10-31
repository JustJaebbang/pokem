-- Apply once before PUSH_ENABLED=true. No existing rows are modified.
CREATE TABLE IF NOT EXISTS push_device (
  installation_id CHAR(32) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  user_id VARCHAR(100) NOT NULL,
  binding_id CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  fid TEXT NOT NULL,
  fid_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
  updated_at DATETIME(6) NOT NULL,
  INDEX push_device_owner (user_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS push_outbox (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_key VARCHAR(150) NOT NULL,
  installation_id CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  binding_id CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id VARCHAR(100) NOT NULL,
  target_code VARCHAR(100) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  next_at DATETIME(6) NOT NULL,
  lease_id CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
  lease_until DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL,
  UNIQUE KEY push_event_device (event_key, installation_id),
  INDEX push_due (status, next_at),
  INDEX push_lease (status, lease_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
