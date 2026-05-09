-- Cleanup existing service_people.full_name values in the live DB.
-- This is needed if you already created the DB before we changed the seed SQL files.

USE facility_service_managemnet_Db;

-- 1) Strip prefixes like "Plant Housekeeping - Ramesh" -> "Ramesh"
UPDATE service_people
SET full_name = TRIM(SUBSTRING_INDEX(full_name, '-', -1))
WHERE full_name LIKE '%-%';

-- 2) Rows like "Plant Housekeeping 1" cannot be auto-converted to a real name.
--    Update them manually as needed, examples:
-- UPDATE service_people SET full_name = 'Ramesh' WHERE full_name = 'Plant Housekeeping 1';
-- UPDATE service_people SET full_name = 'Suresh' WHERE full_name = 'Plant Plumbing 1';

-- Optional: If you are OK clearing and re-seeding all assignees (be careful if tickets already reference assignees):
-- DELETE FROM service_people;
-- SOURCE database/seed_service_people_dummy.sql;

