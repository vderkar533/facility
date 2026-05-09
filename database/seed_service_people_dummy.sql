-- Seed dummy assignees for Assign dropdown
-- Run this after migrations so service_people has service_name/location_name columns.

USE facility_service_managemnet_Db;

-- Optional: clear existing dummy rows (uncomment if you want a clean re-seed)
-- DELETE FROM service_people WHERE email LIKE '%@fsm.com';

INSERT INTO service_people
  (full_name, email, site_area, service_type, service_name, location_name, active)
VALUES
  -- Plant (generic for all services of each type)
  ('Ramesh', 'plant.hk1@fsm.com', 'Plant', 'Housekeeping', NULL, NULL, 1),
  ('Suresh', 'plant.pl1@fsm.com', 'Plant', 'Plumbing', NULL, NULL, 1),
  ('Mahesh', 'plant.pc1@fsm.com', 'Plant', 'Pest Control', NULL, NULL, 1),
  ('Dinesh', 'plant.cp1@fsm.com', 'Plant', 'Carpenter', NULL, NULL, 1),
  ('Raju', 'plant.el1@fsm.com', 'Plant', 'Electrical', NULL, NULL, 1),
  ('Ganesh', 'plant.wt1@fsm.com', 'Plant', 'Water', NULL, NULL, 1),

  -- Guesthouse
  ('Anita', 'guest.hk1@fsm.com', 'Guesthouse', 'Housekeeping', NULL, NULL, 1),
  ('Sunita', 'guest.pl1@fsm.com', 'Guesthouse', 'Plumbing', NULL, NULL, 1),
  ('Kavita', 'guest.pc1@fsm.com', 'Guesthouse', 'Pest Control', NULL, NULL, 1),
  ('Rohit', 'guest.cp1@fsm.com', 'Guesthouse', 'Carpenter', NULL, NULL, 1),
  ('Mohan', 'guest.el1@fsm.com', 'Guesthouse', 'Electrical', NULL, NULL, 1),
  ('Nilesh', 'guest.wt1@fsm.com', 'Guesthouse', 'Water', NULL, NULL, 1),

  -- Colony
  ('Asha', 'colony.hk1@fsm.com', 'Colony', 'Housekeeping', NULL, NULL, 1),
  ('Rekha', 'colony.pl1@fsm.com', 'Colony', 'Plumbing', NULL, NULL, 1),
  ('Seema', 'colony.pc1@fsm.com', 'Colony', 'Pest Control', NULL, NULL, 1),
  ('Prakash', 'colony.cp1@fsm.com', 'Colony', 'Carpenter', NULL, NULL, 1),
  ('Deepak', 'colony.el1@fsm.com', 'Colony', 'Electrical', NULL, NULL, 1),
  ('Kiran', 'colony.wt1@fsm.com', 'Colony', 'Water', NULL, NULL, 1),

  -- Hostel
  ('Imran', 'hostel.hk1@fsm.com', 'Hostel', 'Housekeeping', NULL, NULL, 1),
  ('Farhan', 'hostel.pl1@fsm.com', 'Hostel', 'Plumbing', NULL, NULL, 1),
  ('Salim', 'hostel.pc1@fsm.com', 'Hostel', 'Pest Control', NULL, NULL, 1),
  ('Aarav', 'hostel.cp1@fsm.com', 'Hostel', 'Carpenter', NULL, NULL, 1),
  ('Vivek', 'hostel.el1@fsm.com', 'Hostel', 'Electrical', NULL, NULL, 1),
  ('Sameer', 'hostel.wt1@fsm.com', 'Hostel', 'Water', NULL, NULL, 1),

  -- Hostel booking (specific service)
  ('Priya', 'hostel.book1@fsm.com', 'Hostel', 'Accommodation', 'Book Hostel Room', NULL, 1),
  ('Neha', 'hostel.book2@fsm.com', 'Hostel', 'Accommodation', 'Book Hostel Room', 'Hostel Reception', 1);
