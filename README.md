# Urban Company Home Services Database: DBMS Project

**Course:** Database Management Systems · **Year:** B.Tech 2nd year · **Team size:** 4
**Database:** PostgreSQL 15 or newer · **Final submission:** Mon 23 Nov 2026
**Topics used:** Data types & constraints · Keys & relationships · Normalization · Query execution plans · Indexing · Query optimization · VACUUM/ANALYZE · Partitioning & sharding

## Files in this folder

| Path | What it is |
|------|------------|
| `README.md` | This project brief |
| `seed_data.zip` | 11 CSV files (150,000 bookings): the only input for Phase 2. Unzip it to get `seed_data/` |
| `queries/workload_30.sql` | The 30 queries for Phase 3 (do not edit) |
| `benchmarks/run_benchmark.sh` | Timing script: 3 runs per query, average, raw plans saved |
| `CHECKPOINTS.md` | Checkpoint dates and the files each one needs (DE and AP repos) |

**Getting started:** **clone this repository and push it into your team's DE repo** (the DE repo you submitted in the form); the steps are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Keep the structure shown in [Repository structure](#repository-structure-submit-exactly-this). Unzip `seed_data.zip` inside your project folder, but don't commit the CSV files. Deadlines are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Then begin with Phase 1.

---

## Team details (fill in before you start)

| Role | Name | Enrollment No. | GitHub Username |
|---|---|---|---|
| Group Lead | Rakshit Yadav | 2501010369 | rakshityadav1868 |
| Member 2 | Archit Jain | 2501010579 | Pending |
| Member 3 | Gourav Jain | 2501010551 | Pending |
| Member 4 | Ishaan Goel | 2501010191 | Pending |

**Team No.:** T0114 · **Section:** C · **Repository URL:** https://github.com/rakshityadav1868/Relay_DE_2026

---

## How this project works

| Phase | What you do | You submit | Counts toward | Marks |
|-------|-------------|------------|---------------|------:|
| 1 | Understand the problem statements | `docs/01_problem_understanding.md` | Query Execution | 2 |
| 2 | Work out the database schema **from the seed data** and load it | `sql/01_schema.sql`, `sql/02_load_data.sql`, `docs/02_schema_design.md` | Query Execution | 5 |
| 3 | Run the **30 given SQL queries** and record their execution time | `docs/03_baseline_timings.md`, `benchmarks/results/baseline/` | Query Execution | 3 |
| 4 | Optimize the queries and record the new times | `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `docs/04_optimization_report.md`, `benchmarks/results/optimized/` | Code Optimization | 16 |
| 5 | Scalability test on the **large dataset** (given later by faculty) and final report | `docs/05_scalability_report.md`, `benchmarks/results/large/` | Code Optimization | 14 |
| | **Total** | | | **40** |

---

## Phase 1: Problem statements

Urban Company sends trained **professionals** to people's homes—cleaning, salon, AC repair, plumbing, painting and more. Each professional is skilled in one or more **service categories** and publishes their **availability** for every working day. A customer books a **service** for a time slot; the booking is then **assigned** to a professional, who starts and completes the job (or it is rescheduled, cancelled, or the professional doesn't show up). Customers and professionals **review** each other, UC Plus members get discounts, and professionals are paid **weekly**. You have joined the Urban Company data team.

The current database was put together quickly by an earlier team. It has **no documented schema** (only data exports survive), and the product teams are complaining:

| # | Problem reported | Team | Related queries |
|---|------------------|------|-----------------|
| P1 | "The **service menu** and **slot picker** are slow; the slot picker must check skills, availability and clashing jobs." | Customer app | R01, R02, W01 |
| P2 | "Customers and support wait too long for **My bookings**, booking details and phone lookups." | Customer app / Support | R03, R06, R22, R23 |
| P3 | "The **partner app** (today's jobs, weekly earnings, completing jobs) lags in the field." | Partner app | R04, R07, W03 |
| P4 | "**Dispatch** can't see unassigned jobs about to start fast enough." | Dispatch | R05, W02, W05 |
| P5 | "The partner-rewards list of **pros with no customer cancellations** always comes back **empty**." | Partner success | R13 |
| P6 | "**Quality** reports (late starts, no-shows, low ratings, complaints, unskilled jobs) time out." | Quality | R09, R10, R15, R18, R21 |
| P7 | "**Finance**: payouts, Plus savings, cancellation fees and GMV reports are slow." | Finance | R08, R12, R20, R24, W04 |
| P8 | "Planning reports (reschedules, demand heat-map, pincodes, retention, utilisation, city report) are slow, and bookings will grow **20×**." | Operations / Expansion | R11, R14, R16, R17, R19, R25 |

**Your job:**
1. Rebuild a correct, well-constrained schema from the data exports (Phase 2).
2. Measure how the 30 most important queries perform today (Phase 3).
3. Make them fast **without changing their results** (Phase 4).
4. Prove the database will survive next year's growth (Phase 5).

**Deliverable for Phase 1** (`docs/01_problem_understanding.md`, at most 1 page):
- For each problem P1–P8, write in your own words what the business needs and which **stakeholder** is affected (customer, service professional (partner), dispatch/operations, quality team, UC Plus team, finance (payouts), city expansion, support).
- Classify each problem as **customer-facing / real-time** or **reporting / analytics**. This decides your performance targets later.
- List any assumptions you make.

---

## Phase 2: Work out the schema from the seed data

You receive **`seed_data.zip`**. Unzip it to get a folder **`seed_data/`** with 11 CSV files, a real export of the production data:

| File | Rows | What it contains |
|------|-----:|------------------|
| `cities.csv` | 10 | Cities |
| `service_categories.csv` | 10 | Service categories |
| `services.csv` | 60 | Services that can be booked |
| `professionals.csv` | 2,500 | Service professionals (partners) |
| `pro_skills.csv` | 5,000 | Categories each professional is certified for |
| `pro_availability.csv` | 70,407 | Working hours of each professional per day (Jun–Jul 2026) |
| `customers.csv` | 40,000 | Customers (some are UC Plus members) |
| `bookings.csv` | 150,000 | Every booking from 1 Jan 2025 to 30 Jun 2026 (slots up to early July) |
| `reschedules.csv` | 5,391 | Booking reschedules |
| `reviews.csv` | 76,539 | Ratings and comments after completed jobs |
| `payouts.csv` | 27,015 | Weekly payouts to professionals |

The first line of every file is the header (column names). Here are the headers and the first rows of each file:

**cities.csv**
```
city_id,city_name,state
1,Bengaluru,Karnataka
2,Mumbai,Maharashtra
```

**service_categories.csv**
```
category_id,category_name
1,Home Cleaning
2,Salon for Women
```

**services.csv**
```
service_id,category_id,service_name,duration_min,base_price,is_active
1,1,Full Home Deep Cleaning,300,3999.00,t
2,1,Bathroom Cleaning,60,549.00,t
```

**professionals.csv**
```
pro_id,full_name,phone,city_id,gender,joined_on,rating,kyc_verified,status
1,Ananya Gupta,7000000001,2,M,2019-11-13,4.88,t,ACTIVE
2,Kavya Khan,7000000002,4,M,2025-10-24,4.87,t,SUSPENDED
```

**pro_skills.csv**
```
pro_id,category_id,certified_on
1,3,2019-12-13
1,4,2019-12-13
```

**pro_availability.csv**
```
pro_id,work_date,start_time,end_time
1,2026-06-01,08:00:00,21:00:00
1,2026-06-03,10:00:00,19:00:00
```

**customers.csv**
```
customer_id,full_name,phone,email,city_id,plus_valid_until,created_at
1,Vivaan Sharma,9100000001,,3,,2020-01-19 09:44:52+05:30
2,Aditya Sharma,9100000002,,8,,2019-03-30 21:19:02+05:30
```

**bookings.csv**
```
booking_id,customer_id,service_id,pro_id,city_id,pincode,booked_at,scheduled_start,scheduled_end,started_at,completed_at,status,price,discount,cancellation_fee,tip,payment_method
1,38250,40,175,1,560050,2025-01-01 00:00:00+05:30,2025-01-02 15:00:00+05:30,2025-01-02 15:30:00+05:30,2025-01-02 15:03:00+05:30,2025-01-02 15:33:00+05:30,COMPLETED,193.00,0.00,0.00,,UPI
2,31016,29,311,1,560012,2025-01-01 00:05:14+05:30,2025-01-01 12:00:00+05:30,2025-01-01 12:45:00+05:30,2025-01-01 12:20:00+05:30,2025-01-01 13:05:00+05:30,COMPLETED,415.00,0.00,0.00,,CASH
```

**reschedules.csv**
```
reschedule_id,booking_id,old_start,new_start,requested_by,reason,created_at
1,52,2025-01-04 16:00:00+05:30,2025-01-05 16:00:00+05:30,CUSTOMER,Material not available,2025-01-02 16:18:12.666667+05:30
2,76,2025-01-01 14:00:00+05:30,2025-01-02 14:00:00+05:30,PRO,Rain,2025-01-01 17:02:04.666667+05:30
```

**reviews.csv**
```
booking_id,rating_for_pro,comment,rating_for_customer,created_at
3,3,Overcharged for materials,5,2025-01-06 01:51:00+05:30
5,1,,,2025-01-02 20:27:00+05:30
```

**payouts.csv**
```
payout_id,pro_id,week_start,jobs,gross_earnings,commission,net_payout,status,paid_at
1,1,2026-01-05,1,4159.00,831.80,3327.20,PAID,2026-01-14 11:00:00+05:30
2,3,2026-01-05,2,4950.15,986.03,3964.12,PAID,2026-01-14 11:00:00+05:30
```

Open the files yourself (a spreadsheet, `head`, or `SELECT` after a quick load into a scratch table) and study the data carefully. **Nobody will give you the CREATE TABLE statements.** Working them out *is* the task.

### 2.1 What you must identify (for every table)
1. **Table name and column names.** Use exactly the file names and CSV headers. The 30 queries depend on them.
2. **Data type** of every column. Choose the *right* type, not just `TEXT` everywhere. Think about money, timestamps with a time-zone offset, yes/no columns, small whole numbers, decimals and short codes.
3. **Primary key.** Is it one column, or a combination? (Look closely at `pro_skills`, `pro_availability`, `reviews` (one per booking?) and `payouts` (one per professional per week?).)
4. **Foreign keys.** Which column points to which table? What should happen **ON DELETE** (CASCADE, RESTRICT or SET NULL), and why?
5. **NOT NULL vs NULL.** Some columns are empty in some rows. Find out **when** and **why**, and decide which columns must never be empty. When are `pro_id`, `started_at`, `completed_at`, `tip`, `plus_valid_until`, `rating`, `rating_for_customer` and `paid_at` empty?
6. **UNIQUE** columns (natural candidate keys such as emails, phone numbers, codes and handles).
7. **CHECK constraints.** Write at least **12** that the data obeys and the business needs. Look for allowed values (statuses, gender, requested_by), time rules (slot after booking, end after start, availability end after start, payouts always start on a Monday), money rules (discount ≤ price, net payout = gross − commission, a tip only on completed jobs, a cancellation fee only on customer cancellations) and rules that depend on `status`.
8. **Relationships and cardinalities** (1:1, 1:N, M:N). Draw the **ER diagram** (image + Mermaid code).
9. **Normal form.** Show that each table is in 3NF/BCNF (list its functional dependencies). Point out any column that is *derived or redundant* (hint: `scheduled_end` vs the service duration; `payouts` vs the completed bookings of that week; `professionals.rating` vs reviews) and say whether keeping it is justified.

### 2.2 Rules for your schema
- Create every table in a schema named **`uc`**: `CREATE SCHEMA uc;` and `SET search_path TO uc;`
- In this phase create **only constraints**: PK, FK, UNIQUE, NOT NULL, CHECK. **Do not create any other index yet.** (PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns; that's allowed. Note which indexes exist.) Your baseline in Phase 3 must reflect a database *without* tuning.
- Your constraints must accept **all** rows of the seed data. If a load fails, either your constraint is wrong or you found a data problem. Explain which in your design doc.

### 2.3 Load the data
Write `sql/02_load_data.sql` using `\copy`, loading tables in the right order (parents before children):

```sql
SET search_path TO uc;
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
-- ... the other tables, in an order that satisfies your foreign keys
ANALYZE;
```

Then verify the row counts match the table above, and run at least **3 integrity checks** of your own (e.g. "a professional never has two jobs whose slots overlap", "every job is inside the professional's availability for that day", "payout totals match the completed bookings of that week"). Paste the results into `docs/02_schema_design.md`.

### Phase 2 deliverables
- `sql/01_schema.sql`: runs top-to-bottom on an empty database without errors
- `sql/02_load_data.sql`: loads all 11 files without errors
- `docs/02_schema_design.md`: data dictionary (table · column · type · constraint · *why*), ER diagram, FDs and normal form per table, integrity-check results, and every data problem you found

---

## Phase 3: Run the 30 queries and record the time

The file **`queries/workload_30.sql`** contains **30 queries**: 25 reads (`R01`–`R25`) and 5 writes (`W01`–`W05`). They're also listed in the [Appendix](#appendix-the-30-queries). **Do not modify them.** If a query fails, your schema doesn't match the seed data; fix the schema, not the query.

### 3.1 How to measure (everyone must use the same method)
- Run each query with `EXPLAIN (ANALYZE, BUFFERS)` and read the **`Execution Time`** at the bottom.
- Run each query **3 times** and record the **average** of the three `Execution Time` values. Keep all three runs in the raw plan file.
- Write queries (`W01`–`W05`) must be measured inside `BEGIN; … ROLLBACK;` so the data does not change.
- Close other heavy applications while measuring, and use the **same laptop** for Phase 3 and Phase 4.

The helper script does all of this for you:
```bash
./benchmarks/run_benchmark.sh <your_database> baseline
# → benchmarks/results/baseline/summary.csv   (avg, median, min, max, scan types)
# → benchmarks/results/baseline/R01.txt …     (full plans of all 3 runs)
```
> ⚠️ One of the 30 queries takes **noticeably longer** than the others on the seed data. That's intentional. Let it finish, and don't skip it.

### 3.2 Deliverable: the timing table
In `docs/03_baseline_timings.md`, fill this table for **all 30** queries:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Service menu: active AC Repair services, cheapest first | READ | | | | |
| R02: Slot picker: Bengaluru salon professionals free on 3 July 2026 from 11:00 to 12:30 | READ | | | | |
| R03: "My bookings": customer 226's upcoming bookings | READ | | | | |
| R04: Partner app: professional 425's jobs on 2 July 2026 | READ | | | | |
| R05: Dispatch: requested jobs with no professional that start before noon on 2 July 2026 | READ | | | | |
| R06: Customer support: look up a customer by mobile number | READ | | | | |
| R07: Partner app: professional 425's earnings in the week of 22 June 2026 | READ | | | | |
| R08: Finance: payouts still pending for the week starting 22 June 2026 | READ | | | | |
| R09: Quality: share of June 2026 jobs that started more than 15 minutes late, per category | READ | | | | |
| R10: Quality: no-show rate of professionals with at least 20 assigned jobs | READ | | | | |
| R11: Operations: services rescheduled most often in June 2026 | READ | | | | |
| R12: UC Plus: total discount given to Plus members per month in 2026 | READ | | | | |
| R13: Partner rewards: active professionals who have never had a booking cancelled by a customer | READ | | | | |
| R14: Demand planning: Bengaluru bookings by category, weekday and hour of the scheduled slot | READ | | | | |
| R15: Quality: professionals whose average rating in June 2026 is below 4.0 (at least 5 reviews) | READ | | | | |
| R16: Expansion: top 10 Mumbai pincodes by bookings in June 2026 | READ | | | | |
| R17: Retention: customers who booked the same category 3 or more times in 2026 | READ | | | | |
| R18: Quality: newest reviews complaining about lateness | READ | | | | |
| R19: City report: June 2026 completed jobs and last job date of every active Bengaluru professional | READ | | | | |
| R20: Finance: daily GMV and running total for June 2026 | READ | | | | |
| R21: Compliance: completed jobs done by a professional who is not skilled in that service's category | READ | | | | |
| R22: Support console: all bookings, newest first, page 4,001 (25 per page) | READ | | | | |
| R23: Booking detail page | READ | | | | |
| R24: Finance: cancellation fees collected per month in 2026 | READ | | | | |
| R25: Capacity: utilisation (booked minutes ÷ available minutes) of Bengaluru professionals, 22–28 June 2026 | READ | | | | |
| W01: Customer app: book an AC service for 3 July 2026, 11:00 | WRITE | | | | |
| W02: Dispatch: give the oldest REQUESTED booking to professional 425 | WRITE | | | | |
| W03: Partner app: professional 425 finishes their job on 2 July 2026 and gets a ₹50 tip | WRITE | | | | |
| W04: Finance: create payouts for the week starting 29 June 2026 from completed jobs | WRITE | | | | |
| W05: Operations: assigned jobs whose slot ended before 2 July 2026 without starting become NO_SHOW | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

Below the table, add for each query the **scan type** from the plan (Seq Scan, Index Scan, …) and one line on **why** it is slow or fast.

---

## Phase 4: Optimize the queries

Make the queries faster. **The results must stay the same** (same rows; order matters only where the query has an `ORDER BY`).

### 4.1 Techniques you may use
| Technique | Example |
|-----------|---------|
| B-tree index (single / composite) | the right column **order** matters: equality columns first, then range/sort |
| Partial index | index only the rows a query needs (e.g. a rare status) |
| Covering index | `INCLUDE (...)` so the table is never visited (Index Only Scan) |
| Expression index | index the exact expression used in `WHERE` |
| GIN index | for `ILIKE '%text%'` (extension `pg_trgm`), arrays or full-text search |
| BRIN index | for huge tables stored in time order |
| Query rewrite | sargable date ranges instead of functions on columns; `NOT EXISTS` instead of `NOT IN`; joins instead of correlated subqueries; keyset instead of `OFFSET` pagination; `UNION ALL` instead of `OR` across columns |
| VACUUM / ANALYZE | fresh statistics and visibility maps |
| Summary table / materialized view | for heavy reports that don't need live data (state how it's refreshed) |

**Not allowed:** changing the data, deleting rows, changing PostgreSQL server settings to hide the problem (e.g. huge `work_mem`, `enable_seqscan = off`), or caching results outside the database.

### 4.2 How to work
1. Put every index in `sql/05_indexes.sql`, each with a comment: **which queries it serves and why this type and column order**.
2. Put rewritten queries in `sql/06_optimized_queries.sql`. Copy `queries/workload_30.sql` and change **only** the queries you rewrite, keeping the `-- @R01` markers.
3. **Prove the results are unchanged** for every rewritten query (compare row counts, plus a checksum or an `EXCEPT` query). Put the proof in your report.
4. Benchmark again with the same method:
```bash
./benchmarks/run_benchmark.sh <your_database> optimized 5 sql/06_optimized_queries.sql
```
> 🔎 **Read the results, not just the timings.** At least one of the 30 original queries returns a **wrong answer** because of a subtle SQL rule about NULLs. Find it, explain it, and fix it. This is worth marks.

### 4.3 Deliverable: the optimization table
In `docs/04_optimization_report.md`:

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|-------|------------:|---------------------------|----------------------|-----------:|------------:|:------------:|
| R04 | | e.g. Seq Scan on 150k bookings + DATE() | e.g. index on `bookings(pro_id, scheduled_start)` with a sargable range | | e.g. 99% (120×) | ✅ |
| … all 30 … | | | | | | |
| **Total** | | | | | | |

Improvement % = (before − after) / before × 100

Also include:
- **Before/after `EXPLAIN` plans** for your 5 biggest improvements
- **Write overhead:** which write queries got **slower** because of your indexes, by how much, and whether that's acceptable
- **Index storage:** the size of each index you created (`pg_relation_size`) compared with its table
- **Queries you could not speed up**, and why (an honest "this query must read most of the table" earns marks)

---

## Phase 5: Scalability report (large dataset round)

Your optimizations worked on 150,000 bookings. Next year the business expects **20× the volume**.

By **Thu 19 Nov 2026**, faculty will release **`large_data.zip`**: the same 11 CSV files with about **20× the rows** (≈ 3,000,000 bookings, ≈ 1,531,000 reviews, ≈ 1,408,000 pro availability, ≈ 540,000 payouts, ≈ 800,000 customers). Until then, work on the design part of the report.

### 5.1 What to do with the large dataset
1. Create a new database. Run **your** `01_schema.sql`, load `large_data/` with your load script (change the folder name only), then run **your** `05_indexes.sql` and `ANALYZE`.
2. Run your **optimized** queries (`sql/06_optimized_queries.sql`). **Do not run the original 30 on the large data.** Some of them could run for a very long time.
   - R22 pages with `OFFSET`; if you replaced it with keyset pagination, explain how the "last seen" value is chosen for the large data.
3. Record the times and compare with your Phase 4 results on the seed data.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|:-------------:|--------------------------|
| R01 | | | | | |
| … all 30 … | | | | | |

### 5.2 Performance targets on the large dataset
| Query group | Queries | Target (average of 3 runs) |
|-------------|---------|----------------:|
| Real-time / app-facing | R01, R02, R03, R04, R05, R06, R07, R23, W01, W02, W03 | **under 5 ms** |
| Interactive operations tools | R08, R11, R13, R16, R18, R22, W05 | **under 250 ms** |
| Reports and analytics | R09, R10, R12, R14, R15, R17, R19, R20, R21, R24, R25 | **under 5,000 ms** |
| Batch jobs | W04 | **under 1,000 ms** |

If a query misses its target, **find out why from the plan and fix it.** A query that was fast on the seed data can become slow on large data for reasons that only appear at scale. Show the before/after plans for every fix.

### 5.3 Deliverable: `docs/05_scalability_report.md`
1. **Results table** (above), with every target met or explained.
2. **Growth analysis.** Group your queries by how their time grew when the data grew 20×:
   - *stayed about the same* (why? e.g. index lookups grow with log n)
   - *grew about 20×* (why? e.g. they read a fixed *share* of the table)
   - *grew more than 20×* (why, and what you did about it)
3. **What broke at scale** and how you fixed it (plans before/after).
4. **Storage:** total database size, table vs index size, on seed and large data.
5. **Architecture for 100×:** explain with numbers from your own measurements:
   - **Partitioning:** which table, by which column (RANGE / LIST / HASH), and why. Write the DDL for `bookings`, show partition pruning with `EXPLAIN`, and note the primary-key rule for partitioned tables.
   - **Sharding:** Would you shard by city, by professional, or by customer? A booking is local to one city—but quality and finance reports span the country. Which queries become cross-shard, and how would you handle them?
   - **Read replicas and caching:** which of the 30 queries you would send to a replica or cache, and which must hit the primary.
   - **Maintenance:** VACUUM/autovacuum settings for `bookings`, archiving old data, refreshing summary tables.
6. **Conclusion:** is your database ready for next year? What are the remaining risks?

---

## Repository structure (submit exactly this)

```
urbancompany-dbms-<team-no>/
├── README.md                          # team table, how to run, headline numbers
├── team.json                          # group lead, members, enrollment numbers
├── docs/
│   ├── 01_problem_understanding.md
│   ├── 02_schema_design.md
│   ├── 03_baseline_timings.md
│   ├── 04_optimization_report.md
│   └── 05_scalability_report.md
├── diagrams/
│   └── er_diagram.png
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   ├── 05_indexes.sql
│   ├── 06_optimized_queries.sql
│   └── 08_partitioning.sql
├── queries/
│   └── workload_30.sql                # given; do not edit
└── benchmarks/
    ├── run_benchmark.sh               # given
    └── results/
        ├── baseline/                  # Phase 3: summary.csv + raw plans
        ├── optimized/                 # Phase 4
        └── large/                     # Phase 5
```

`team.json`:
```json
{
  "team_number": "",
  "group_lead": { "name": "", "enrollment_no": "", "github": "" },
  "members": [
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" }
  ],
  "postgres_version": "",
  "laptop_used_for_benchmarks": ""
}
```

**Do not commit the CSV files** (`seed_data/`, `large_data/`); add them to `.gitignore`. They are too large and we already have them.

---

## Timeline

| Due | Work | Checkpoint |
|-----|------|------------|
| Tue 3 Nov 2026 | Clone this repo into your team's DE repo, add members, commit `team.json` | **CP0** Setup |
| Mon 16 Nov 2026 | Phase 1 + Phase 2 (schema, load, ER, data dictionary) | **CP1** Schema loads all seed data with no errors |
| Tue 17 Nov 2026 | Phase 3 (baseline, 3 runs, average) + start Phase 4 | **CP2** Baseline table for all 30 queries committed |
| Thu 19 Nov 2026 | Phase 4 (indexes, rewrites, wrong-result query) | **CP3** Optimization table committed |
| Mon 23 Nov 2026 | Phase 5 on the large dataset + final report | **CP4 Final submission:** last commit on the default branch |
| Wed 25 – Thu 26 Nov 2026 | Individual analysis, in class time | **CP5** Individual analysis |

Full list of files per checkpoint, including the AP repo: [`CHECKPOINTS.md`](CHECKPOINTS.md).

---

## Evaluation (40 marks)

These 40 marks are the DE part of the project: **Query Execution (10)** and **Code Optimization (30)**.
The AP project (20) and your Individual analysis (40) make up the rest of the 100.

| Phase | Criteria | Marks |
|-------|----------|------:|
| | **Query Execution** | **10** |
| 1 | Problems understood, stakeholders and query groups correctly identified | 2 |
| 2 | Correct data types (1), keys and foreign keys with justified delete rules (1), ≥12 meaningful CHECK / NOT NULL / UNIQUE constraints (1), ER diagram + normal-form analysis (1), data loads cleanly + integrity checks (1) | 5 |
| 3 | All 30 queries measured with the required method: 3 runs, average (1), raw plans committed (1), scan type and reason for each query (1) | 3 |
| | **Code Optimization** | **30** |
| 4 | Speed-up achieved with appropriate techniques (6), every index justified (3), results proven unchanged (2), wrong-result query found and explained (2), write overhead and index storage reported (3) | 16 |
| 5 | Large-dataset results with all targets met or explained (4), growth analysis (3), scale-only problems found and fixed (3), partitioning DDL + sharding/replica design backed by your numbers (4) | 14 |
| | **Total** | **40** |

**Integrity rules**
- Every number in your reports must match the raw plan files in `benchmarks/results/`. Copied or invented timings make the whole phase score 0.
- Every member must have commits; the commit history is checked.
- You may use AI tools to learn, but you must be able to explain every index and rewrite in your individual analysis.

---

## Appendix: the 30 queries

These are identical to `queries/workload_30.sql`. Use the file, not copy-paste from this page.

**R01: Service menu: active AC Repair services, cheapest first**
```sql
SELECT s.service_id, s.service_name, s.duration_min, s.base_price
FROM services s
JOIN service_categories c ON c.category_id = s.category_id
WHERE c.category_name = 'AC Repair' AND s.is_active
ORDER BY s.base_price;
```

**R02: Slot picker: Bengaluru salon professionals free on 3 July 2026 from 11:00 to 12:30**
```sql
SELECT p.pro_id, p.full_name, p.rating
FROM professionals p
JOIN pro_skills ps       ON ps.pro_id = p.pro_id
JOIN service_categories c ON c.category_id = ps.category_id AND c.category_name = 'Salon for Women'
JOIN pro_availability a  ON a.pro_id = p.pro_id AND a.work_date = '2026-07-03'
WHERE p.city_id = 1 AND p.status = 'ACTIVE'
  AND a.start_time <= '11:00' AND a.end_time >= '12:30'
  AND NOT EXISTS (SELECT 1 FROM bookings b
                  WHERE b.pro_id = p.pro_id
                    AND b.status IN ('ASSIGNED', 'IN_PROGRESS')
                    AND b.scheduled_start < '2026-07-03 12:30:00+05:30'
                    AND b.scheduled_end   > '2026-07-03 11:00:00+05:30')
ORDER BY p.rating DESC NULLS LAST
LIMIT 10;
```

**R03: "My bookings": customer 226's upcoming bookings**
```sql
SELECT b.booking_id, s.service_name, b.scheduled_start, b.status, p.full_name AS professional
FROM bookings b
JOIN services s ON s.service_id = b.service_id
LEFT JOIN professionals p ON p.pro_id = b.pro_id
WHERE b.customer_id = 226
  AND b.scheduled_start >= '2026-07-01'
ORDER BY b.scheduled_start;
```

**R04: Partner app: professional 425's jobs on 2 July 2026**
```sql
SELECT b.booking_id, s.service_name, b.scheduled_start, b.scheduled_end, b.pincode, b.status
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.pro_id = 425
  AND DATE(b.scheduled_start) = '2026-07-02'
ORDER BY b.scheduled_start;
```

**R05: Dispatch: requested jobs with no professional that start before noon on 2 July 2026**
```sql
SELECT booking_id, service_id, city_id, scheduled_start
FROM bookings
WHERE status = 'REQUESTED'
  AND scheduled_start < '2026-07-02 12:00:00+05:30'
ORDER BY scheduled_start;
```

**R06: Customer support: look up a customer by mobile number**
```sql
SELECT customer_id, full_name, city_id, plus_valid_until
FROM customers
WHERE phone = '9100001042';
```

**R07: Partner app: professional 425's earnings in the week of 22 June 2026**
```sql
SELECT count(*) AS jobs, sum(price - discount) AS service_value, coalesce(sum(tip), 0) AS tips
FROM bookings
WHERE pro_id = 425 AND status = 'COMPLETED'
  AND completed_at >= '2026-06-22' AND completed_at < '2026-06-29';
```

**R08: Finance: payouts still pending for the week starting 22 June 2026**
```sql
SELECT po.payout_id, po.pro_id, p.full_name, po.jobs, po.net_payout
FROM payouts po
JOIN professionals p ON p.pro_id = po.pro_id
WHERE po.status = 'PENDING' AND po.week_start = '2026-06-22'
ORDER BY po.net_payout DESC;
```

**R09: Quality: share of June 2026 jobs that started more than 15 minutes late, per category**
```sql
SELECT c.category_name, count(*) AS jobs,
       round(100.0 * count(*) FILTER (WHERE b.started_at > b.scheduled_start + interval '15 minutes') / count(*), 1) AS late_pct
FROM bookings b
JOIN services s           ON s.service_id = b.service_id
JOIN service_categories c ON c.category_id = s.category_id
WHERE b.status = 'COMPLETED'
  AND b.scheduled_start >= '2026-06-01' AND b.scheduled_start < '2026-07-01'
GROUP BY c.category_name
ORDER BY late_pct DESC;
```

**R10: Quality: no-show rate of professionals with at least 20 assigned jobs**
```sql
SELECT pro_id, count(*) AS jobs,
       round(100.0 * count(*) FILTER (WHERE status = 'NO_SHOW') / count(*), 2) AS no_show_pct
FROM bookings
WHERE pro_id IS NOT NULL
GROUP BY pro_id
HAVING count(*) >= 20
ORDER BY no_show_pct DESC
LIMIT 20;
```

**R11: Operations: services rescheduled most often in June 2026**
```sql
SELECT s.service_name, count(*) AS reschedules,
       count(*) FILTER (WHERE r.requested_by = 'PRO') AS by_pro
FROM reschedules r
JOIN bookings b ON b.booking_id = r.booking_id
JOIN services s ON s.service_id = b.service_id
WHERE r.created_at >= '2026-06-01' AND r.created_at < '2026-07-01'
GROUP BY s.service_name
ORDER BY reschedules DESC
LIMIT 10;
```

**R12: UC Plus: total discount given to Plus members per month in 2026**
```sql
SELECT date_trunc('month', b.booked_at) AS month, count(*) AS bookings, sum(b.discount) AS plus_savings
FROM bookings b
WHERE b.discount > 0
  AND EXTRACT(YEAR FROM b.booked_at) = 2026
GROUP BY 1
ORDER BY 1;
```

**R13: Partner rewards: active professionals who have never had a booking cancelled by a customer**
```sql
SELECT p.pro_id, p.full_name, p.rating
FROM professionals p
WHERE p.status = 'ACTIVE'
  AND p.pro_id NOT IN (SELECT b.pro_id FROM bookings b WHERE b.status = 'CANCELLED_BY_CUSTOMER');
```

**R14: Demand planning: Bengaluru bookings by category, weekday and hour of the scheduled slot**
```sql
SELECT s.category_id, EXTRACT(ISODOW FROM b.scheduled_start) AS weekday, EXTRACT(HOUR FROM b.scheduled_start) AS hour, count(*) AS bookings
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.city_id = 1
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
```

**R15: Quality: professionals whose average rating in June 2026 is below 4.0 (at least 5 reviews)**
```sql
SELECT b.pro_id, round(avg(r.rating_for_pro), 2) AS avg_rating, count(*) AS reviews
FROM reviews r
JOIN bookings b ON b.booking_id = r.booking_id
WHERE r.created_at >= '2026-06-01' AND r.created_at < '2026-07-01'
GROUP BY b.pro_id
HAVING count(*) >= 5 AND avg(r.rating_for_pro) < 4.0
ORDER BY avg_rating;
```

**R16: Expansion: top 10 Mumbai pincodes by bookings in June 2026**
```sql
SELECT pincode, count(*) AS bookings
FROM bookings
WHERE city_id = 2
  AND booked_at >= '2026-06-01' AND booked_at < '2026-07-01'
GROUP BY pincode
ORDER BY bookings DESC
LIMIT 10;
```

**R17: Retention: customers who booked the same category 3 or more times in 2026**
```sql
SELECT b.customer_id, s.category_id, count(*) AS bookings
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.booked_at >= '2026-01-01' AND b.status = 'COMPLETED'
GROUP BY b.customer_id, s.category_id
HAVING count(*) >= 3
ORDER BY bookings DESC, b.customer_id;
```

**R18: Quality: newest reviews complaining about lateness**
```sql
SELECT r.booking_id, r.rating_for_pro, r.comment, r.created_at
FROM reviews r
WHERE r.comment ILIKE '%late%'
ORDER BY r.created_at DESC
LIMIT 50;
```

**R19: City report: June 2026 completed jobs and last job date of every active Bengaluru professional**
```sql
SELECT p.pro_id, p.full_name,
       (SELECT count(*) FROM bookings b WHERE b.pro_id = p.pro_id AND b.status = 'COMPLETED'
          AND b.scheduled_start >= '2026-06-01' AND b.scheduled_start < '2026-07-01') AS june_jobs,
       (SELECT max(b.completed_at) FROM bookings b WHERE b.pro_id = p.pro_id) AS last_job_at
FROM professionals p
WHERE p.city_id = 1 AND p.status = 'ACTIVE'
ORDER BY june_jobs DESC;
```

**R20: Finance: daily GMV and running total for June 2026**
```sql
SELECT day, gmv, sum(gmv) OVER (ORDER BY day) AS running_gmv
FROM (
    SELECT scheduled_start::date AS day, sum(price - discount) AS gmv
    FROM bookings
    WHERE status = 'COMPLETED'
      AND scheduled_start::date BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY 1
) d
ORDER BY day;
```

**R21: Compliance: completed jobs done by a professional who is not skilled in that service's category**
```sql
SELECT b.booking_id, b.pro_id, s.service_name
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.status = 'COMPLETED'
  AND NOT EXISTS (SELECT 1 FROM pro_skills ps WHERE ps.pro_id = b.pro_id AND ps.category_id = s.category_id)
ORDER BY b.booking_id;
```

**R22: Support console: all bookings, newest first, page 4,001 (25 per page)**
```sql
SELECT booking_id, customer_id, service_id, status, booked_at
FROM bookings
ORDER BY booked_at DESC
OFFSET 100000
LIMIT 25;
```

**R23: Booking detail page**
```sql
SELECT b.*, s.service_name
FROM bookings b
JOIN services s ON s.service_id = b.service_id
WHERE b.booking_id = 123456;
```

**R24: Finance: cancellation fees collected per month in 2026**
```sql
SELECT date_trunc('month', scheduled_start) AS month, count(*) AS charged_cancellations, sum(cancellation_fee) AS fees
FROM bookings
WHERE cancellation_fee > 0
  AND scheduled_start >= '2026-01-01'
GROUP BY 1
ORDER BY 1;
```

**R25: Capacity: utilisation (booked minutes ÷ available minutes) of Bengaluru professionals, 22–28 June 2026**
```sql
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
```

**W01: Customer app: book an AC service for 3 July 2026, 11:00**
```sql
INSERT INTO bookings (booking_id, customer_id, service_id, city_id, pincode, booked_at, scheduled_start, scheduled_end,
                      status, price, payment_method)
VALUES (90000001, 226, 19, 1, '560034', '2026-07-01 09:00:00+05:30', '2026-07-03 11:00:00+05:30',
        '2026-07-03 11:45:00+05:30', 'REQUESTED', 599.00, 'UPI');
```

**W02: Dispatch: give the oldest REQUESTED booking to professional 425**
```sql
UPDATE bookings
SET pro_id = 425, status = 'ASSIGNED'
WHERE booking_id = (SELECT min(booking_id) FROM bookings WHERE status = 'REQUESTED');
```

**W03: Partner app: professional 425 finishes their job on 2 July 2026 and gets a ₹50 tip**
```sql
UPDATE bookings
SET status = 'COMPLETED', started_at = scheduled_start, completed_at = scheduled_end, tip = 50
WHERE pro_id = 425 AND status = 'ASSIGNED'
  AND scheduled_start >= '2026-07-02' AND scheduled_start < '2026-07-03';
```

**W04: Finance: create payouts for the week starting 29 June 2026 from completed jobs**
```sql
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
```

**W05: Operations: assigned jobs whose slot ended before 2 July 2026 without starting become NO_SHOW**
```sql
UPDATE bookings
SET status = 'NO_SHOW'
WHERE status = 'ASSIGNED'
  AND scheduled_end < '2026-07-02 00:00:00+05:30'
  AND started_at IS NULL;
```
