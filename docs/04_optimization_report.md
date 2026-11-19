# Optimization Report

Benchmark results comparing baseline (CP2) and optimized (CP3) timings on PostgreSQL 15.
All 30 queries were run 3 times and average execution times are shown below.

| Query | Type | What it does | Baseline (ms) | Optimized (ms) | Improvement |
|---|---|---|---:|---:|---:|
| R01 | READ | Active AC repair services by price | 0.259 | 0.154 | 40.5% (1.7x) |
| R02 | READ | Free Bengaluru salon pros for slot | 13.845 | 1.954 | 85.9% (7.1x) |
| R03 | READ | Customer 226 upcoming bookings | 9.808 | 0.360 | 96.3% (27.2x) |
| R04 | READ | Professional 425 jobs on 2 July 2026 | 8.539 | 0.261 | 96.9% (32.7x) |
| R05 | READ | Unassigned requested jobs before noon | 13.666 | 0.215 | 98.4% (63.6x) |
| R06 | READ | Look up customer by phone number | 0.031 | 0.064 | -106.5% |
| R07 | READ | Professional 425 weekly earnings | 9.396 | 0.550 | 94.1% (17.1x) |
| R08 | READ | Pending payouts for week of 22 June 2026 | 2.909 | 2.053 | 29.4% (1.4x) |
| R09 | READ | Share of late jobs by category | 8.157 | 8.744 | -7.2% |
| R10 | READ | No-show rate of pros with 20+ jobs | 22.936 | 27.091 | -18.1% |
| R11 | READ | Most rescheduled services in June 2026 | 0.961 | 0.682 | 29.0% (1.4x) |
| R12 | READ | Monthly Plus discounts in 2026 | 10.317 | 7.690 | 25.5% (1.3x) |
| R13 | READ | Active pros with no customer cancellations | 10.546 | 4.564 | 56.7% (2.3x) |
| R14 | READ | Bengaluru bookings by category, day, hour | 25.245 | 23.012 | 8.8% (1.1x) |
| R15 | READ | Pros with average rating below 4.0 | 13.874 | 11.786 | 15.0% (1.2x) |
| R16 | READ | Top 10 Mumbai pincodes in June 2026 | 6.078 | 0.728 | 88.0% (8.3x) |
| R17 | READ | Repeat customers with 3+ bookings in category | 18.007 | 15.181 | 15.7% (1.2x) |
| R18 | READ | Reviews complaining about lateness | 10.117 | 0.139 | 98.6% (72.8x) |
| R19 | READ | June jobs and last job of Bengaluru pros | 3632.158 | 44.303 | 98.8% (82.0x) |
| R20 | READ | Daily and running GMV for June 2026 | 9.471 | 2.392 | 74.7% (4.0x) |
| R21 | READ | Completed jobs by unskilled pros | 16.996 | 17.474 | -2.8% |
| R22 | READ | All bookings paginated (page 4001) | 31.693 | 11.641 | 63.3% (2.7x) |
| R23 | READ | Booking details by ID | 0.056 | 0.080 | -42.9% |
| R24 | READ | Monthly cancellation fees in 2026 | 10.966 | 8.945 | 18.4% (1.2x) |
| R25 | READ | Utilisation of Bengaluru pros in June | 2237.143 | 11.805 | 99.5% (189.5x) |
| W01 | WRITE | Book an AC service slot | 0.702 | 0.746 | -6.3% |
| W02 | WRITE | Assign oldest requested booking to pro | 13.919 | 17.571 | -26.2% |
| W03 | WRITE | Complete booking and add tip | 8.471 | 0.381 | 95.5% (22.2x) |
| W04 | WRITE | Create weekly payouts from completed jobs | 10.454 | 14.424 | -38.0% |
| W05 | WRITE | Mark expired unstarted bookings as no-show | 8.641 | 4.796 | 44.5% (1.8x) |
| Total | | | 6140.732 | 239.516 | 96.1% (25.6x) |

## Why queries got faster

- **R19 and R25:** Both queries had correlated subqueries that ran for each professional. In baseline, each subquery did a full table scan on 150,000 bookings. Adding an index on `bookings(pro_id)` let PostgreSQL use index lookups, reducing R19 from ~3632 ms to ~44 ms and R25 from ~2237 ms to ~11 ms.
- **R02:** Reordered the joins so the smaller table `service_categories` is filtered first, and used the new indexes on `pro_skills(category_id)` and `bookings(status)`.
- **R03, R04, and R07:** Adding indexes on `bookings(customer_id)` and `bookings(pro_id)` allowed direct index scans instead of scanning the full bookings table.
- **R04, R12, and R20:** Replaced functions like `DATE()` and `EXTRACT()` on date columns with simple `>=` and `<` date ranges so PostgreSQL could use the index on `scheduled_start` and `booked_at`.
- **R05 and W05:** An index on `bookings(status)` allowed finding requested and assigned jobs quickly without scanning the entire table.
- **R13:** Replaced `NOT IN` with `NOT EXISTS`. In baseline, NULL values in `pro_id` caused `NOT IN` to return empty results. Using `NOT EXISTS` fixed the bug and used the `bookings(pro_id)` index.
- **R16 and R22:** Index on `bookings(booked_at)` avoided a full table scan for R16 and avoided sorting 150,000 rows on disk for R22.
- **R23:** Changed `SELECT *` to select only the required columns.
- **Queries with little or no speedup (R10, R14, R21):** These queries aggregate or process large portions of the bookings table (e.g. R10 checks almost all bookings where `pro_id` is not null), so a sequential scan is already the best choice.
