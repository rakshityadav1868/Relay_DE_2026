# Baseline Timings

Benchmark results for the 30 queries on PostgreSQL 15.17 on a MacBook Pro (macOS).
The tests were run on the uc schema with 150,000 bookings.
There are no indexes except primary and unique keys.
Each query was run 3 times and the average execution time was recorded.

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|---|---|---|---:|---:|---:|---:|---|
| R01 | READ | Active AC repair services by price | 0.413 | 0.218 | 0.147 | 0.259 | Seq Scan (services, service_categories) |
| R02 | READ | Free Bengaluru salon pros for slot | 20.792 | 10.968 | 9.775 | 13.845 | Seq Scan (pro_skills, professionals, service_categories, bookings), Index Scan (pro_availability) |
| R03 | READ | Customer 226 upcoming bookings | 10.406 | 9.806 | 9.213 | 9.808 | Seq Scan (bookings, services), Index Scan (professionals) |
| R04 | READ | Professional 425 jobs on 2 July 2026 | 8.952 | 8.521 | 8.143 | 8.539 | Seq Scan (bookings, services) |
| R05 | READ | Unassigned requested jobs before noon | 14.994 | 13.795 | 12.208 | 13.666 | Seq Scan (bookings) |
| R06 | READ | Look up customer by phone number | 0.028 | 0.027 | 0.038 | 0.031 | Index Scan (customers) |
| R07 | READ | Professional 425 weekly earnings | 9.241 | 9.729 | 9.218 | 9.396 | Seq Scan (bookings) |
| R08 | READ | Pending payouts for week of 22 June 2026 | 2.099 | 3.527 | 3.101 | 2.909 | Seq Scan (professionals, payouts) |
| R09 | READ | Share of late jobs by category | 10.506 | 7.225 | 6.740 | 8.157 | Seq Scan (bookings, services, service_categories) |
| R10 | READ | No-show rate of pros with 20+ jobs | 24.993 | 22.620 | 21.194 | 22.936 | Seq Scan (bookings) |
| R11 | READ | Most rescheduled services in June 2026 | 1.142 | 0.935 | 0.806 | 0.961 | Seq Scan (reschedules), Index Scan (bookings, services) |
| R12 | READ | Monthly Plus discounts in 2026 | 10.805 | 10.087 | 10.058 | 10.317 | Seq Scan (bookings) |
| R13 | READ | Active pros with no customer cancellations | 9.242 | 11.299 | 11.098 | 10.546 | Seq Scan (professionals, bookings) |
| R14 | READ | Bengaluru bookings by category, day, hour | 21.157 | 22.909 | 31.669 | 25.245 | Seq Scan (bookings, services) |
| R15 | READ | Pros with average rating below 4.0 | 14.202 | 13.603 | 13.817 | 13.874 | Seq Scan (bookings, reviews) |
| R16 | READ | Top 10 Mumbai pincodes in June 2026 | 6.170 | 5.968 | 6.097 | 6.078 | Seq Scan (bookings) |
| R17 | READ | Repeat customers with 3+ bookings in category | 17.441 | 16.001 | 20.580 | 18.007 | Seq Scan (bookings, services) |
| R18 | READ | Reviews complaining about lateness | 10.726 | 10.175 | 9.450 | 10.117 | Seq Scan (reviews) |
| R19 | READ | June jobs and last job of Bengaluru pros | 3529.092 | 3766.646 | 3600.735 | 3632.158 | Seq Scan (professionals, bookings) |
| R20 | READ | Daily and running GMV for June 2026 | 9.575 | 9.533 | 9.304 | 9.471 | Seq Scan (bookings) |
| R21 | READ | Completed jobs by unskilled pros | 17.057 | 17.245 | 16.685 | 16.996 | Seq Scan (bookings, services, pro_skills) |
| R22 | READ | All bookings paginated (page 4001) | 31.666 | 31.680 | 31.732 | 31.693 | Seq Scan (bookings) |
| R23 | READ | Booking details by ID | 0.050 | 0.064 | 0.053 | 0.056 | Seq Scan (services), Index Scan (bookings) |
| R24 | READ | Monthly cancellation fees in 2026 | 12.239 | 10.126 | 10.532 | 10.966 | Seq Scan (bookings) |
| R25 | READ | Utilisation of Bengaluru pros in June | 2222.327 | 2253.355 | 2235.747 | 2237.143 | Index Scan (professionals), Seq Scan (pro_availability, bookings) |
| W01 | WRITE | Book an AC service slot | 0.764 | 0.648 | 0.695 | 0.702 | None |
| W02 | WRITE | Assign oldest requested booking to pro | 14.835 | 14.146 | 12.775 | 13.919 | Index Scan (bookings) |
| W03 | WRITE | Complete booking and add tip | 8.752 | 8.317 | 8.344 | 8.471 | Seq Scan (bookings) |
| W04 | WRITE | Create weekly payouts from completed jobs | 11.008 | 10.232 | 10.122 | 10.454 | Seq Scan (bookings) |
| W05 | WRITE | Mark expired unstarted bookings as no-show | 8.899 | 8.616 | 8.407 | 8.641 | Seq Scan (bookings) |

## Slowest queries

1. **R19 (3632.158 ms):** It runs two correlated subqueries for every active professional in Bengaluru. Each subquery does a sequential scan over the 150,000 rows in bookings.
2. **R25 (2237.143 ms):** It has a correlated subquery in the SELECT clause that scans all bookings for each professional. It also joins availability rows using a nested loop.
3. **R22 (31.693 ms):** It scans all 150,000 bookings and sorts them on disk using an external merge sort to reach offset 100,000.
4. **R14 (25.245 ms):** It sequentially scans bookings to filter for Bengaluru rows, joins with services, and sorts about 24,000 rows by three expressions before grouping.
5. **R10 (22.936 ms):** It does a sequential scan on almost the entire bookings table to filter assigned jobs, followed by aggregation and sorting.
