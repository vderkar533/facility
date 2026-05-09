-- Adds user-managed catalog rows for service locations and service names.
-- The backend merges these rows with the defaults in backend/src/config/catalog.js.

CREATE TABLE IF NOT EXISTS catalog_locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  location_name VARCHAR(120) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_catalog_location (site_area, location_name)
);

CREATE TABLE IF NOT EXISTS catalog_services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_catalog_service (site_area, service_type, service_name)
);

CREATE TABLE IF NOT EXISTS catalog_disabled_locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  location_name VARCHAR(120) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_disabled_catalog_location (site_area, location_name)
);

CREATE TABLE IF NOT EXISTS catalog_disabled_services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_disabled_catalog_service (site_area, service_type, service_name)
);
