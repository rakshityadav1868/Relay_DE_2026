-- =====================================================================
-- Urban Company Home Services Database: Schema Definition (Phase 2)
-- Target: PostgreSQL 15+
-- Schema: uc
--
-- Tables (in dependency order):
--  1. cities
--  2. service_categories
--  3. services
--  4. professionals
--  5. pro_skills
--  6. pro_availability
--  7. customers
--  8. bookings
--  9. reschedules
-- 10. reviews
-- 11. payouts
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS uc;
SET search_path TO uc;

-- Drop existing tables in reverse dependency order for clean re-runs
DROP TABLE IF EXISTS payouts CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS reschedules CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS pro_availability CASCADE;
DROP TABLE IF EXISTS pro_skills CASCADE;
DROP TABLE IF EXISTS professionals CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS service_categories CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

-- ---------------------------------------------------------------------
-- 1. cities: Service operational locations across India
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id   INTEGER PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE,
    state     VARCHAR(100) NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. service_categories: Broad service industry classifications
-- ---------------------------------------------------------------------
CREATE TABLE service_categories (
    category_id   INTEGER PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 3. services: Bookable offerings with duration and base pricing
-- ---------------------------------------------------------------------
CREATE TABLE services (
    service_id   INTEGER PRIMARY KEY,
    category_id  INTEGER NOT NULL REFERENCES service_categories(category_id) ON DELETE RESTRICT,
    service_name VARCHAR(150) NOT NULL UNIQUE,
    duration_min SMALLINT NOT NULL CHECK (duration_min > 0),
    base_price   NUMERIC(10, 2) NOT NULL CHECK (base_price >= 0),
    is_active    BOOLEAN NOT NULL
);

-- ---------------------------------------------------------------------
-- 4. professionals: Service partners providing services in cities
-- ---------------------------------------------------------------------
CREATE TABLE professionals (
    pro_id       INTEGER PRIMARY KEY,
    full_name    VARCHAR(150) NOT NULL,
    phone        VARCHAR(20) NOT NULL UNIQUE,
    city_id      INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    gender       CHAR(1) NOT NULL CHECK (gender IN ('M', 'F')),
    joined_on    DATE NOT NULL,
    rating       NUMERIC(3, 2) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),
    kyc_verified BOOLEAN NOT NULL,
    status       VARCHAR(20) NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'OFFBOARDED'))
);

-- ---------------------------------------------------------------------
-- 5. pro_skills: Certifications linking professionals to service categories
-- ---------------------------------------------------------------------
CREATE TABLE pro_skills (
    pro_id       INTEGER NOT NULL REFERENCES professionals(pro_id) ON DELETE RESTRICT,
    category_id  INTEGER NOT NULL REFERENCES service_categories(category_id) ON DELETE RESTRICT,
    certified_on DATE NOT NULL,
    PRIMARY KEY (pro_id, category_id)
);

-- ---------------------------------------------------------------------
-- 6. pro_availability: Working hours published by professionals per date
-- ---------------------------------------------------------------------
CREATE TABLE pro_availability (
    pro_id     INTEGER NOT NULL REFERENCES professionals(pro_id) ON DELETE RESTRICT,
    work_date  DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time   TIME NOT NULL,
    PRIMARY KEY (pro_id, work_date),
    CONSTRAINT check_availability_times CHECK (end_time > start_time)
);

-- ---------------------------------------------------------------------
-- 7. customers: Registered users who book home services
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id      INTEGER PRIMARY KEY,
    full_name        VARCHAR(150) NOT NULL,
    phone            VARCHAR(20) NOT NULL UNIQUE,
    email            VARCHAR(255) UNIQUE,
    city_id          INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    plus_valid_until DATE,
    created_at       TIMESTAMPTZ NOT NULL
);

-- ---------------------------------------------------------------------
-- 8. bookings: Service appointments, fulfillment lifecycle, and billing
-- ---------------------------------------------------------------------
CREATE TABLE bookings (
    booking_id       INTEGER PRIMARY KEY,
    customer_id      INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    service_id       INTEGER NOT NULL REFERENCES services(service_id) ON DELETE RESTRICT,
    pro_id           INTEGER REFERENCES professionals(pro_id) ON DELETE RESTRICT,
    city_id          INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    pincode          VARCHAR(10) NOT NULL,
    booked_at        TIMESTAMPTZ NOT NULL,
    scheduled_start  TIMESTAMPTZ NOT NULL,
    scheduled_end    TIMESTAMPTZ NOT NULL,
    started_at       TIMESTAMPTZ,
    completed_at     TIMESTAMPTZ,
    status           VARCHAR(30) NOT NULL CHECK (status IN (
                         'REQUESTED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED',
                         'CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_PRO', 'NO_SHOW'
                     )),
    price            NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    discount         NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    cancellation_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (cancellation_fee >= 0),
    tip              NUMERIC(10, 2) CHECK (tip IS NULL OR tip >= 0),
    payment_method   VARCHAR(20) NOT NULL CHECK (payment_method IN ('UPI', 'CASH', 'CARD', 'WALLET')),
    CONSTRAINT check_booking_schedule CHECK (scheduled_end > scheduled_start),
    CONSTRAINT check_scheduled_after_booked CHECK (scheduled_start >= booked_at),
    CONSTRAINT check_discount_le_price CHECK (discount <= price),
    CONSTRAINT check_cancellation_fee_rule CHECK (
        cancellation_fee = 0 OR (status = 'CANCELLED_BY_CUSTOMER' AND cancellation_fee > 0)
    ),
    CONSTRAINT check_tip_completed_rule CHECK (
        tip IS NULL OR (status = 'COMPLETED' AND tip >= 0)
    ),
    CONSTRAINT check_completed_timestamps CHECK (
        (status = 'COMPLETED' AND started_at IS NOT NULL AND completed_at IS NOT NULL AND completed_at >= started_at)
        OR (status <> 'COMPLETED' AND started_at IS NULL AND completed_at IS NULL)
    )
);

-- ---------------------------------------------------------------------
-- 9. reschedules: Audit log of appointment slot adjustments
-- ---------------------------------------------------------------------
CREATE TABLE reschedules (
    reschedule_id INTEGER PRIMARY KEY,
    booking_id    INTEGER NOT NULL REFERENCES bookings(booking_id) ON DELETE RESTRICT,
    old_start     TIMESTAMPTZ NOT NULL,
    new_start     TIMESTAMPTZ NOT NULL,
    requested_by  VARCHAR(20) NOT NULL CHECK (requested_by IN ('CUSTOMER', 'PRO')),
    reason        TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL,
    CONSTRAINT check_reschedule_start_changed CHECK (new_start <> old_start)
);

-- ---------------------------------------------------------------------
-- 10. reviews: Post-service ratings and feedback
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    booking_id          INTEGER PRIMARY KEY REFERENCES bookings(booking_id) ON DELETE RESTRICT,
    rating_for_pro      SMALLINT NOT NULL CHECK (rating_for_pro BETWEEN 1 AND 5),
    comment             TEXT,
    rating_for_customer SMALLINT CHECK (rating_for_customer IS NULL OR rating_for_customer BETWEEN 1 AND 5),
    created_at          TIMESTAMPTZ NOT NULL
);

-- ---------------------------------------------------------------------
-- 11. payouts: Weekly aggregated earnings and settlements for partners
-- ---------------------------------------------------------------------
CREATE TABLE payouts (
    payout_id      INTEGER PRIMARY KEY,
    pro_id         INTEGER NOT NULL REFERENCES professionals(pro_id) ON DELETE RESTRICT,
    week_start     DATE NOT NULL CHECK (EXTRACT(ISODOW FROM week_start) = 1),
    jobs           INTEGER NOT NULL CHECK (jobs > 0),
    gross_earnings NUMERIC(12, 2) NOT NULL CHECK (gross_earnings >= 0),
    commission     NUMERIC(12, 2) NOT NULL CHECK (commission >= 0 AND commission <= gross_earnings),
    net_payout     NUMERIC(12, 2) NOT NULL CHECK (net_payout = gross_earnings - commission),
    status         VARCHAR(20) NOT NULL CHECK (status IN ('PAID', 'PENDING')),
    paid_at        TIMESTAMPTZ,
    CONSTRAINT uq_payouts_pro_week UNIQUE (pro_id, week_start),
    CONSTRAINT check_payout_paid_at_rule CHECK (
        (status = 'PAID' AND paid_at IS NOT NULL)
        OR (status = 'PENDING' AND paid_at IS NULL)
    )
);
