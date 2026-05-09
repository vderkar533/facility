USE facility_service_managemnet_Db;

SET @has_password := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'service_people'
    AND COLUMN_NAME = 'password'
);
SET @stmt := IF(@has_password = 0,
  'ALTER TABLE service_people ADD COLUMN password VARCHAR(120) NOT NULL DEFAULT ''service123'' AFTER email',
  'SELECT 1');
PREPARE service_people_password_stmt FROM @stmt;
EXECUTE service_people_password_stmt;
DEALLOCATE PREPARE service_people_password_stmt;

SET @has_pending_status := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tickets'
    AND COLUMN_NAME = 'pending_service_status'
);
SET @stmt := IF(@has_pending_status = 0,
  'ALTER TABLE tickets ADD COLUMN pending_service_status ENUM(''Resolved'', ''Not Resolved'') NULL AFTER admin_remark',
  'SELECT 1');
PREPARE tickets_pending_status_stmt FROM @stmt;
EXECUTE tickets_pending_status_stmt;
DEALLOCATE PREPARE tickets_pending_status_stmt;

SET @has_pending_remark := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tickets'
    AND COLUMN_NAME = 'pending_service_remark'
);
SET @stmt := IF(@has_pending_remark = 0,
  'ALTER TABLE tickets ADD COLUMN pending_service_remark TEXT NULL AFTER pending_service_status',
  'SELECT 1');
PREPARE tickets_pending_remark_stmt FROM @stmt;
EXECUTE tickets_pending_remark_stmt;
DEALLOCATE PREPARE tickets_pending_remark_stmt;

SET @has_pending_updated_at := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tickets'
    AND COLUMN_NAME = 'pending_service_updated_at'
);
SET @stmt := IF(@has_pending_updated_at = 0,
  'ALTER TABLE tickets ADD COLUMN pending_service_updated_at TIMESTAMP NULL AFTER pending_service_remark',
  'SELECT 1');
PREPARE tickets_pending_updated_stmt FROM @stmt;
EXECUTE tickets_pending_updated_stmt;
DEALLOCATE PREPARE tickets_pending_updated_stmt;

ALTER TABLE ticket_events
  MODIFY actor_role ENUM('normal_user', 'admin_user', 'service_person', 'system') NOT NULL;

UPDATE service_people
SET password = 'service123'
WHERE password IS NULL OR TRIM(password) = '';

UPDATE service_people
SET active = 1
WHERE active IS NULL;
