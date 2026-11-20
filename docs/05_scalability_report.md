# Scalability Report

Benchmark results comparing optimized queries from CP3 with the partitioned table setup in CP4 on PostgreSQL 15.
All 30 queries were run 3 times using the benchmark script and average execution times are shown below.

| Query | Type | What it does | Optimized CP3 (ms) | Large/Partitioned CP4 (ms) | Target (ms) | Meets target? |
|---|---|---|---:|---:|---:|:---:|
| R01 | READ | Active AC repair services by price | 0.154 | 0.079 | < 5 | Yes |
| R02 | READ | Free Bengaluru salon pros for slot | 1.954 | 0.926 | < 5 | Yes |
| R03 | READ | Customer 226 upcoming bookings | 0.360 | 0.054 | < 5 | Yes |
| R04 | READ | Professional 425 jobs on 2 July 2026 | 0.261 | 0.052 | < 5 | Yes |
| R05 | READ | Unassigned requested jobs before noon | 0.215 | 0.073 | < 5 | Yes |
| R06 | READ | Look up customer by phone number | 0.064 | 0.026 | < 5 | Yes |
| R07 | READ | Professional 425 weekly earnings | 0.550 | 0.222 | < 5 | Yes |
| R08 | READ | Pending payouts for week of 22 June 2026 | 2.053 | 0.580 | < 250 | Yes |
| R09 | READ | Share of late jobs by category | 8.744 | 2.732 | < 5000 | Yes |
| R10 | READ | No-show rate of pros with 20+ jobs | 27.091 | 11.196 | < 5000 | Yes |
| R11 | READ | Most rescheduled services in June 2026 | 0.682 | 0.620 | < 250 | Yes |
| R12 | READ | Monthly Plus discounts in 2026 | 7.690 | 4.127 | < 5000 | Yes |
| R13 | READ | Active pros with no customer cancellations | 4.564 | 3.736 | < 250 | Yes |
| R14 | READ | Bengaluru bookings by category, day, hour | 23.012 | 18.350 | < 5000 | Yes |
| R15 | READ | Pros with average rating below 4.0 | 11.786 | 16.846 | < 5000 | Yes |
| R16 | READ | Top 10 Mumbai pincodes in June 2026 | 0.728 | 0.694 | < 250 | Yes |
| R17 | READ | Repeat customers with 3+ bookings in category | 15.181 | 12.730 | < 5000 | Yes |
| R18 | READ | Reviews complaining about lateness | 0.139 | 0.184 | < 250 | Yes |
| R19 | READ | June jobs and last job of Bengaluru pros | 44.303 | 13.315 | < 5000 | Yes |
| R20 | READ | Daily and running GMV for June 2026 | 2.392 | 3.520 | < 5000 | Yes |
| R21 | READ | Completed jobs by unskilled pros | 17.474 | 17.791 | < 5000 | Yes |
| R22 | READ | All bookings paginated (page 4001) | 11.641 | 13.243 | < 250 | Yes |
| R23 | READ | Booking details by ID | 0.080 | 0.060 | < 5 | Yes |
| R24 | READ | Monthly cancellation fees in 2026 | 8.945 | 3.612 | < 5000 | Yes |
| R25 | READ | Utilisation of Bengaluru pros in June | 11.805 | 8.584 | < 5000 | Yes |
| W01 | WRITE | Book an AC service slot | 0.746 | 0.783 | < 5 | Yes |
| W02 | WRITE | Assign oldest requested booking to pro | 17.571 | 0.576 | < 5 | Yes |
| W03 | WRITE | Complete booking and add tip | 0.381 | 0.166 | < 5 | Yes |
| W04 | WRITE | Create weekly payouts from completed jobs | 14.424 | 9.834 | < 1000 | Yes |
| W05 | WRITE | Mark expired unstarted bookings as no-show | 4.796 | 1.163 | < 250 | Yes |

## How partitioning helped

We chose range partitioning on `bookings` using the `scheduled_start` column. We split the data into three partitions: `bookings_2025` for all 2025 bookings, `bookings_2026_h1` for January to June 2026, and `bookings_2026_h2` for July 2026 onward.

The main benefit comes from partition pruning. When a query filters by date, PostgreSQL checks the partition boundaries and skips partitions that cannot contain matching rows:

- **R03 and R04:** Both queries look for upcoming bookings in July 2026 (`scheduled_start >= '2026-07-01'`). The query planner only scans `bookings_2026_h2` and completely ignores `bookings_2025` (which has 100,000 rows) and `bookings_2026_h1`. Execution time dropped from 0.360 ms to 0.054 ms for R03 and from 0.261 ms to 0.052 ms for R04.
- **R09, R19, and R25:** These queries analyze jobs in June 2026 (`scheduled_start >= '2026-06-01' AND scheduled_start < '2026-07-01'`). Because of pruning, the engine only scans `bookings_2026_h1`. R09 dropped from 8.744 ms to 2.732 ms, and R19 dropped from 44.303 ms to 13.315 ms.
- **R24:** Calculates cancellation fees for 2026 (`scheduled_start >= '2026-01-01'`). It skips the entire `bookings_2025` partition, cutting execution time from 8.945 ms to 3.612 ms.
- **W03:** Updating an assigned booking in July 2026 only touches `bookings_2026_h2`, reducing write time from 0.381 ms to 0.166 ms.

## Where partitioning did not help

Partitioning did not help queries that do not filter on `scheduled_start`:
- **R10, R14, R15, R21:** These queries aggregate across all bookings or filter by `city_id` or `status` without a date filter. PostgreSQL has to scan all three partitions (`bookings_2025`, `bookings_2026_h1`, `bookings_2026_h2`). Their timings remained similar to CP3 (for example, R14 went from 23.0 ms to 18.3 ms, and R21 remained around 17.5 ms).
- **R18 and R06:** These queries do not touch the `bookings` table at all (`reviews` and `customers`), so partitioning `bookings` has no effect on them.

## PostgreSQL primary key rule

In PostgreSQL, when a table is partitioned, every unique constraint and primary key on the table must include all partitioning columns. Because we partitioned `bookings` by `scheduled_start`, we could not have a primary key on just `booking_id`. We had to change the primary key to `(booking_id, scheduled_start)`.

Also, PostgreSQL does not allow a foreign key on another table to reference a partitioned table unless it matches the full unique key. As a result, the foreign key references from `reviews(booking_id)` and `reschedules(booking_id)` to `bookings(booking_id)` had to be removed.

## Storage breakdown

Storage sizes on disk after partitioning:
- `bookings_2025`: 13 MB table + 9.8 MB indexes = 23 MB total
- `bookings_2026_h1`: 6.7 MB table + 5.1 MB indexes = 12 MB total
- `bookings_2026_h2`: 64 kB table + 208 kB indexes = 304 kB total
- Total `bookings` data + indexes: ~35 MB
- Entire database size: ~70 MB

Indexes on smaller partitions fit better in memory (PostgreSQL buffer cache), which keeps index lookups fast as data grows.

## Scaling considerations for 100x

- **Sharding:** If data grows 100x, sharding by `city_id` makes the most sense because most customer and professional activity is local to a single city. However, country-wide reports (like R09, R10, R20) would need cross-shard queries or an aggregated reporting database.
- **Read replicas:** Heavy analytical queries like R10, R14, R17, and R20 can be routed to read replicas so they do not block real-time operations on the primary. Real-time booking queries (R03, R04, R06, W01, W02, W03) stay on the primary.
- **Maintenance:** With range partitioning, older partitions like `bookings_2025` become read-only and do not need frequent vacuuming. We can run VACUUM and ANALYZE on individual active partitions like `bookings_2026_h2` much faster, and very old data can be detached and archived easily without rewriting the entire table.
