CREATE DATABASE IF NOT EXISTS facility_service_managemnet_Db;
USE facility_service_managemnet_Db;

DROP TABLE IF EXISTS ticket_events;
DROP TABLE IF EXISTS tickets;
DROP TABLE IF EXISTS service_people;
DROP TABLE IF EXISTS catalog_disabled_services;
DROP TABLE IF EXISTS catalog_disabled_locations;
DROP TABLE IF EXISTS catalog_services;
DROP TABLE IF EXISTS catalog_locations;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  password VARCHAR(120) NOT NULL,
  role ENUM('normal_user', 'admin_user', 'admin', 'super_admin') NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE service_people (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(120) NOT NULL,
  password VARCHAR(120) NOT NULL DEFAULT 'service123',
  site_area ENUM('Plant', 'Guesthouse', 'Colony', 'Hostel') NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80),
  location_name VARCHAR(120),
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE catalog_locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  location_name VARCHAR(120) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_catalog_location (site_area, location_name)
);

CREATE TABLE catalog_services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_catalog_service (site_area, service_type, service_name)
);

CREATE TABLE catalog_disabled_locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  location_name VARCHAR(120) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_disabled_catalog_location (site_area, location_name)
);

CREATE TABLE catalog_disabled_services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  site_area VARCHAR(40) NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_disabled_catalog_service (site_area, service_type, service_name)
);

CREATE TABLE tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_number VARCHAR(30) UNIQUE,
  user_id INT NOT NULL,
  site_area ENUM('Plant', 'Guesthouse', 'Colony', 'Hostel') NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80) NOT NULL,
  location_name VARCHAR(120) NOT NULL,
  remarks TEXT,
  status ENUM('Open', 'Hold', 'Resolved', 'Cancelled') NOT NULL DEFAULT 'Open',
  admin_remark TEXT,
  pending_service_status ENUM('Resolved', 'Not Resolved') NULL,
  pending_service_remark TEXT,
  pending_service_updated_at TIMESTAMP NULL,
  assigned_person_id INT,
  reopen_count INT NOT NULL DEFAULT 0,
  escalation_level INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_tickets_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_tickets_assigned_person FOREIGN KEY (assigned_person_id) REFERENCES service_people(id)
);

CREATE TABLE ticket_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_id INT NOT NULL,
  actor_role ENUM('normal_user', 'admin_user', 'service_person', 'system') NOT NULL,
  actor_id INT,
  action VARCHAR(40) NOT NULL,
  from_status VARCHAR(20),
  to_status VARCHAR(20),
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ticket_events_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
);

INSERT INTO users (full_name, email, password, role) VALUES
('Normal User', 'user@fsm.com', 'user123', 'normal_user'),
('Admin User', 'admin@fsm.com', 'admin123', 'admin_user');

INSERT INTO service_people (full_name, email, password, site_area, service_type, service_name, location_name) VALUES
('Ramesh', 'plant.housekeeping1@fsm.com', 'service123', 'Plant', 'Housekeeping', NULL, NULL),
('Suresh', 'plant.plumbing1@fsm.com', 'service123', 'Plant', 'Plumbing', NULL, NULL),
('Raju', 'plant.electrical1@fsm.com', 'service123', 'Plant', 'Electrical', NULL, NULL),
('Anita', 'guest.housekeeping1@fsm.com', 'service123', 'Guesthouse', 'Housekeeping', NULL, NULL),
('Sunita', 'guest.plumbing1@fsm.com', 'service123', 'Guesthouse', 'Plumbing', NULL, NULL),
('Asha', 'colony.housekeeping1@fsm.com', 'service123', 'Colony', 'Housekeeping', NULL, NULL),
('Priya', 'hostel.booking1@fsm.com', 'service123', 'Hostel', 'Accommodation', 'Book Hostel Room', NULL);
