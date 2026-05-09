-- Migration: add service_name/location_name to service_people safely
USE facility_service_managemnet_Db;

SET @has_service_name := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'service_people'
    AND COLUMN_NAME = 'service_name'
);
SET @stmt := IF(@has_service_name = 0, 'ALTER TABLE service_people ADD COLUMN service_name VARCHAR(80) NULL', 'SELECT 1');
PREPARE s FROM @stmt;
EXECUTE s;
DEALLOCATE PREPARE s;

SET @has_location_name := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'service_people'
    AND COLUMN_NAME = 'location_name'
);
SET @stmt2 := IF(@has_location_name = 0, 'ALTER TABLE service_people ADD COLUMN location_name VARCHAR(120) NULL', 'SELECT 1');
PREPARE s2 FROM @stmt2;
EXECUTE s2;
DEALLOCATE PREPARE s2;

