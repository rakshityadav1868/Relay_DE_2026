-- Phase 2: load the seed data into the uc schema.
-- Run from the project root (so the seed_data/ paths resolve), after sql/01_schema.sql:
--   psql -d <database> -f sql/02_load_data.sql
-- Parents are loaded before children so every foreign key is satisfied.
SET search_path TO uc;

\copy cities             FROM 'seed_data/cities.csv'             WITH (FORMAT csv, HEADER true)
\copy service_categories FROM 'seed_data/service_categories.csv' WITH (FORMAT csv, HEADER true)
\copy services           FROM 'seed_data/services.csv'           WITH (FORMAT csv, HEADER true)
\copy professionals      FROM 'seed_data/professionals.csv'      WITH (FORMAT csv, HEADER true)
\copy pro_skills         FROM 'seed_data/pro_skills.csv'         WITH (FORMAT csv, HEADER true)
\copy pro_availability   FROM 'seed_data/pro_availability.csv'   WITH (FORMAT csv, HEADER true)
\copy customers          FROM 'seed_data/customers.csv'          WITH (FORMAT csv, HEADER true)
\copy bookings           FROM 'seed_data/bookings.csv'           WITH (FORMAT csv, HEADER true)
\copy reschedules        FROM 'seed_data/reschedules.csv'        WITH (FORMAT csv, HEADER true)
\copy reviews            FROM 'seed_data/reviews.csv'            WITH (FORMAT csv, HEADER true)
\copy payouts            FROM 'seed_data/payouts.csv'            WITH (FORMAT csv, HEADER true)

-- Refresh planner statistics after the bulk load.
ANALYZE;
