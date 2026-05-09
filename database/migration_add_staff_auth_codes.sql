-- Migration: staff auth roles and code-gated account flows.
-- Verification codes and temporary refresh tokens are kept in backend memory.

USE facility_service_managemnet_Db;

ALTER TABLE users
  MODIFY role ENUM('normal_user', 'admin_user', 'admin', 'super_admin') NOT NULL;

UPDATE users
SET role = 'admin_user'
WHERE role = 'admin';
