-- Migration: Hostel + assignment + escalation/event logs
-- Apply to an existing facility_service_managemnet_Db database.

USE facility_service_managemnet_Db;

CREATE TABLE IF NOT EXISTS service_people (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(120) NOT NULL,
  site_area ENUM('Plant', 'Guesthouse', 'Colony', 'Hostel') NOT NULL,
  service_type VARCHAR(60) NOT NULL,
  service_name VARCHAR(80),
  location_name VARCHAR(120),
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ticket_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_id INT NOT NULL,
  actor_role ENUM('normal_user', 'admin_user', 'system') NOT NULL,
  actor_id INT,
  action VARCHAR(40) NOT NULL,
  from_status VARCHAR(20),
  to_status VARCHAR(20),
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Extend tickets table.
ALTER TABLE tickets
  MODIFY site_area ENUM('Plant', 'Guesthouse', 'Colony', 'Hostel') NOT NULL;

ALTER TABLE tickets
  ADD COLUMN assigned_person_id INT NULL,
  ADD COLUMN reopen_count INT NOT NULL DEFAULT 0,
  ADD COLUMN escalation_level INT NOT NULL DEFAULT 0;

ALTER TABLE tickets
  ADD CONSTRAINT fk_tickets_assigned_person
  FOREIGN KEY (assigned_person_id) REFERENCES service_people(id);

ALTER TABLE ticket_events
  ADD CONSTRAINT fk_ticket_events_ticket
  FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE;
