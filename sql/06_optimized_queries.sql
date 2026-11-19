SET search_path TO uc;
BEGIN;

-- @R01
SELECT s.service_id, s.service_name, s.duration_min, s.base_price
FROM services s
JOIN service_categories c ON c.category_id = s.category_id
WHERE c.category_name = 'AC Repair' AND s.is_active
ORDER BY s.base_price;

-- @R02
SELECT p.pro_id, p.full_name, p.rating
FROM service_categories c
JOIN pro_skills ps ON ps.category_id = c.category_id
JOIN professionals p ON p.pro_id = ps.pro_id
JOIN pro_availability a ON a.pro_id = p.pro_id
WHERE c.category_name = 'Salon for Women'
  AND p.city_id = 1 AND p.status = 'ACTIVE'
  AND a.work_date = '2026-07-03'
  AND a.start_time <= '11:00' AND a.end_time >= '12:30'
  AND NOT EXISTS (SELECT 1 FROM bookings b
                  WHERE b.pro_id = p.pro_id
                    AND b.status IN ('ASSIGNED', 'IN_PROGRESS')
                    AND b.scheduled_start < '2026-07-03 12:30:00+05:30'
                    AND b.scheduled_end > '2026-07-03 11:00:00+05:30')
ORDER BY p.rating DESC NULLS LAST
LIMIT 10;

-- @R03
SELECT b.booking_id, s.service_name, b.scheduled_start, b.status, p.full_name AS professional
FROM bookings b
JOIN services s ON s.service_id = b.service_id
LEFT JOIN professionals p ON p.pro_id = b.pro_id
WHERE b.customer_id = 226
  AND b.scheduled_start >= '2026-07-01'
ORDER BY b.scheduled_start;

-- @R04
SELECT b.booking_id, s.service_name, b.scheduled_start, b.scheduled_end, b.pincode, b.status
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.pro_id = 425
  AND b.scheduled_start >= '2026-07-02'
  AND b.scheduled_start < '2026-07-03'
ORDER BY b.scheduled_start;

-- @R05
SELECT booking_id, service_id, city_id, scheduled_start
FROM bookings
WHERE status = 'REQUESTED'
  AND scheduled_start < '2026-07-02 12:00:00+05:30'
ORDER BY scheduled_start;

-- @R06
SELECT customer_id, full_name, city_id, plus_valid_until
FROM customers
WHERE phone = '9100001042';

-- @R07
SELECT count(*) AS jobs, sum(price - discount) AS service_value, coalesce(sum(tip), 0) AS tips
FROM bookings
WHERE pro_id = 425 AND status = 'COMPLETED'
  AND completed_at >= '2026-06-22' AND completed_at < '2026-06-29';

-- @R08
SELECT po.payout_id, po.pro_id, p.full_name, po.jobs, po.net_payout
FROM payouts po
JOIN professionals p ON p.pro_id = po.pro_id
WHERE po.status = 'PENDING' AND po.week_start = '2026-06-22'
ORDER BY po.net_payout DESC;

-- @R09
SELECT c.category_name, count(*) AS jobs,
       round(100.0 * count(*) FILTER (WHERE b.started_at > b.scheduled_start + interval '15 minutes') / count(*), 1) AS late_pct
FROM bookings b
JOIN services s ON s.service_id = b.service_id
JOIN service_categories c ON c.category_id = s.category_id
WHERE b.status = 'COMPLETED'
  AND b.scheduled_start >= '2026-06-01' AND b.scheduled_start < '2026-07-01'
GROUP BY c.category_name
ORDER BY late_pct DESC;

-- @R10
SELECT pro_id, count(*) AS jobs,
       round(100.0 * count(*) FILTER (WHERE status = 'NO_SHOW') / count(*), 2) AS no_show_pct
FROM bookings
WHERE pro_id IS NOT NULL
GROUP BY pro_id
HAVING count(*) >= 20
ORDER BY no_show_pct DESC
LIMIT 20;

-- @R11
SELECT s.service_name, count(*) AS reschedules,
       count(*) FILTER (WHERE r.requested_by = 'PRO') AS by_pro
FROM reschedules r
JOIN bookings b ON b.booking_id = r.booking_id
JOIN services s ON s.service_id = b.service_id
WHERE r.created_at >= '2026-06-01' AND r.created_at < '2026-07-01'
GROUP BY s.service_name
ORDER BY reschedules DESC
LIMIT 10;

-- @R12
SELECT date_trunc('month', b.booked_at) AS month, count(*) AS bookings, sum(b.discount) AS plus_savings
FROM bookings b
WHERE b.discount > 0
  AND b.booked_at >= '2026-01-01'
  AND b.booked_at < '2027-01-01'
GROUP BY 1
ORDER BY 1;

-- @R13
SELECT p.pro_id, p.full_name, p.rating
FROM professionals p
WHERE p.status = 'ACTIVE'
  AND NOT EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.pro_id = p.pro_id
      AND b.status = 'CANCELLED_BY_CUSTOMER'
  );

-- @R14
SELECT s.category_id, EXTRACT(ISODOW FROM b.scheduled_start) AS weekday, EXTRACT(HOUR FROM b.scheduled_start) AS hour, count(*) AS bookings
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.city_id = 1
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- @R15
SELECT b.pro_id, round(avg(r.rating_for_pro), 2) AS avg_rating, count(*) AS reviews
FROM reviews r
JOIN bookings b ON b.booking_id = r.booking_id
WHERE r.created_at >= '2026-06-01' AND r.created_at < '2026-07-01'
GROUP BY b.pro_id
HAVING count(*) >= 5 AND avg(r.rating_for_pro) < 4.0
ORDER BY avg_rating;

-- @R16
SELECT pincode, count(*) AS bookings
FROM bookings
WHERE city_id = 2
  AND booked_at >= '2026-06-01' AND booked_at < '2026-07-01'
GROUP BY pincode
ORDER BY bookings DESC
LIMIT 10;

-- @R17
SELECT b.customer_id, s.category_id, count(*) AS bookings
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.booked_at >= '2026-01-01' AND b.status = 'COMPLETED'
GROUP BY b.customer_id, s.category_id
HAVING count(*) >= 3
ORDER BY bookings DESC, b.customer_id;

-- @R18
SELECT r.booking_id, r.rating_for_pro, r.comment, r.created_at
FROM reviews r
WHERE r.comment ILIKE '%late%'
ORDER BY r.created_at DESC
LIMIT 50;

-- @R19
SELECT p.pro_id, p.full_name,
       (SELECT count(*) FROM bookings b WHERE b.pro_id = p.pro_id AND b.status = 'COMPLETED'
          AND b.scheduled_start >= '2026-06-01' AND b.scheduled_start < '2026-07-01') AS june_jobs,
       (SELECT max(b.completed_at) FROM bookings b WHERE b.pro_id = p.pro_id) AS last_job_at
FROM professionals p
WHERE p.city_id = 1 AND p.status = 'ACTIVE'
ORDER BY june_jobs DESC;

-- @R20
SELECT day, gmv, sum(gmv) OVER (ORDER BY day) AS running_gmv
FROM (
    SELECT scheduled_start::date AS day, sum(price - discount) AS gmv
    FROM bookings
    WHERE status = 'COMPLETED'
      AND scheduled_start >= '2026-06-01' AND scheduled_start < '2026-07-01'
    GROUP BY 1
) d
ORDER BY day;

-- @R21
SELECT b.booking_id, b.pro_id, s.service_name
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.status = 'COMPLETED'
  AND NOT EXISTS (SELECT 1 FROM pro_skills ps WHERE ps.pro_id = b.pro_id AND ps.category_id = s.category_id)
ORDER BY b.booking_id;

-- @R22
SELECT booking_id, customer_id, service_id, status, booked_at
FROM bookings
ORDER BY booked_at DESC
OFFSET 100000
LIMIT 25;

-- @R23
SELECT b.booking_id, b.customer_id, b.service_id, b.pro_id, b.city_id, b.pincode,
       b.booked_at, b.scheduled_start, b.scheduled_end, b.started_at, b.completed_at,
       b.status, b.price, b.discount, b.cancellation_fee, b.tip, b.payment_method,
       s.service_name
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.booking_id = 123456;

-- @R24
SELECT date_trunc('month', scheduled_start) AS month, count(*) AS charged_cancellations, sum(cancellation_fee) AS fees
FROM bookings
WHERE cancellation_fee > 0
  AND scheduled_start >= '2026-01-01'
GROUP BY 1
ORDER BY 1;

-- @R25
SELECT a.pro_id,
       sum(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 60) AS available_min,
       coalesce((SELECT sum(EXTRACT(EPOCH FROM (b.scheduled_end - b.scheduled_start)) / 60)
                 FROM bookings b
                 WHERE b.pro_id = a.pro_id AND b.status = 'COMPLETED'
                   AND b.scheduled_start >= '2026-06-22' AND b.scheduled_start < '2026-06-29'), 0) AS booked_min
FROM pro_availability a
JOIN professionals p ON p.pro_id = a.pro_id AND p.city_id = 1
WHERE a.work_date BETWEEN '2026-06-22' AND '2026-06-28'
GROUP BY a.pro_id
ORDER BY booked_min DESC
LIMIT 30;

-- @W01
INSERT INTO bookings (booking_id, customer_id, service_id, city_id, pincode, booked_at, scheduled_start, scheduled_end,
                      status, price, payment_method)
VALUES (90000001, 226, 19, 1, '560034', '2026-07-01 09:00:00+05:30', '2026-07-03 11:00:00+05:30',
        '2026-07-03 11:45:00+05:30', 'REQUESTED', 599.00, 'UPI');

-- @W02
UPDATE bookings
SET pro_id = 425, status = 'ASSIGNED'
WHERE booking_id = (SELECT min(booking_id) FROM bookings WHERE status = 'REQUESTED');

-- @W03
UPDATE bookings
SET status = 'COMPLETED', started_at = scheduled_start, completed_at = scheduled_end, tip = 50
WHERE pro_id = 425 AND status = 'ASSIGNED'
  AND scheduled_start >= '2026-07-02' AND scheduled_start < '2026-07-03';

-- @W04
INSERT INTO payouts (payout_id, pro_id, week_start, jobs, gross_earnings, commission, net_payout, status)
SELECT 90000000 + pro_id, pro_id, DATE '2026-06-29', count(*),
       sum(price - discount + coalesce(tip, 0)),
       round(sum(price - discount) * 0.20, 2),
       sum(price - discount + coalesce(tip, 0)) - round(sum(price - discount) * 0.20, 2),
       'PENDING'
FROM bookings
WHERE status = 'COMPLETED'
  AND completed_at >= '2026-06-29' AND completed_at < '2026-07-06'
GROUP BY pro_id;

-- @W05
UPDATE bookings
SET status = 'NO_SHOW'
WHERE status = 'ASSIGNED'
  AND scheduled_end < '2026-07-02 00:00:00+05:30'
  AND started_at IS NULL;

-- @END
ROLLBACK;
