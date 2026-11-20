SET search_path TO uc;

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_fkey;
ALTER TABLE reschedules DROP CONSTRAINT IF EXISTS reschedules_booking_id_fkey;

CREATE TABLE bookings_partitioned (
    booking_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    pro_id INTEGER,
    city_id INTEGER NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    booked_at TIMESTAMPTZ NOT NULL,
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    status VARCHAR(30) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    cancellation_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    tip NUMERIC(10, 2),
    payment_method VARCHAR(20) NOT NULL,
    PRIMARY KEY (booking_id, scheduled_start)
) PARTITION BY RANGE (scheduled_start);

CREATE TABLE bookings_2025 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

CREATE TABLE bookings_2026_h1 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');

CREATE TABLE bookings_2026_h2 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2027-01-01 00:00:00+05:30');

INSERT INTO bookings_partitioned SELECT * FROM bookings;

DROP TABLE bookings CASCADE;

ALTER TABLE bookings_partitioned RENAME TO bookings;

CREATE INDEX idx_bookings_pro_id ON bookings (pro_id);
CREATE INDEX idx_bookings_customer_id ON bookings (customer_id);
CREATE INDEX idx_bookings_status ON bookings (status);
CREATE INDEX idx_bookings_scheduled_start ON bookings (scheduled_start);
CREATE INDEX idx_bookings_booked_at ON bookings (booked_at);
CREATE INDEX idx_bookings_city_id ON bookings (city_id);

ANALYZE bookings;
