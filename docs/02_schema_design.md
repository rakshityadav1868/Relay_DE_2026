# Phase 2 schema design

I based this design on the 11 CSV exports in `seed_data/`. The schema uses PostgreSQL types that keep money exact, retain the UTC offset in event times, and treat phone numbers and pincodes as identifiers. I did not find an existing `sql/01_schema.sql` in the repository.

## Tables and columns

`PK` is a primary key, `FK` is a foreign key, `UQ` is unique, `NN` is not null, and `CK` is a check. All foreign keys below use `ON DELETE RESTRICT`: these rows are historical or operational records, so removing a referenced city, service, person, booking, or category would silently erase or invalidate meaningful records. Parent rows must be retired or cleaned up deliberately. PostgreSQL also uses `RESTRICT` by default if no action is written.

### `cities` — service locations

| Column | Type | Rules and reason |
|---|---|---|
| `city_id` | integer | PK, NN; stable identifier. |
| `city_name` | text | NN, UQ; one row per city name. |
| `state` | text | NN; state/territory name. |

### `service_categories` — broad service groups

| Column | Type | Rules and reason |
|---|---|---|
| `category_id` | integer | PK, NN; stable identifier. |
| `category_name` | text | NN, UQ; category names are distinct in the export and used in reports. |

### `services` — bookable offerings

| Column | Type | Rules and reason |
|---|---|---|
| `service_id` | integer | PK, NN. |
| `category_id` | integer | FK → `service_categories.category_id`, NN, RESTRICT; each offering belongs to one category. |
| `service_name` | text | NN, UQ; names are distinct in the export. |
| `duration_min` | smallint | NN, CK > 0; duration is a positive whole number of minutes. |
| `base_price` | numeric(10,2) | NN, CK >= 0; exact currency amount. |
| `is_active` | boolean | NN; whether it is offered now. |

### `professionals` — service professionals

| Column | Type | Rules and reason |
|---|---|---|
| `pro_id` | integer | PK, NN. |
| `full_name` | text | NN. |
| `phone` | varchar(20) | NN, UQ; keep as text because it is an identifier, not a quantity. |
| `city_id` | integer | FK → `cities.city_id`, NN, RESTRICT; current home/service city. |
| `gender` | char(1) | NN, CK in (`M`,`F`); the only exported codes. |
| `joined_on` | date | NN. |
| `rating` | numeric(3,2) | NULL allowed, CK between 0 and 5 when present; an un-rated professional has no aggregate yet. |
| `kyc_verified` | boolean | NN. |
| `status` | varchar(12) | NN, CK in (`ACTIVE`,`SUSPENDED`,`OFFBOARDED`); exported lifecycle values. |

### `pro_skills` — professional certifications by category

| Column | Type | Rules and reason |
|---|---|---|
| `pro_id` | integer | PK part, FK → `professionals.pro_id`, NN, RESTRICT. |
| `category_id` | integer | PK part, FK → `service_categories.category_id`, NN, RESTRICT. |
| `certified_on` | date | NN. |

The pair `(pro_id, category_id)` is the PK: a professional should have one certification record per category, while either id alone can occur many times.

### `pro_availability` — a professional's working window on a date

| Column | Type | Rules and reason |
|---|---|---|
| `pro_id` | integer | PK part, FK → `professionals.pro_id`, NN, RESTRICT. |
| `work_date` | date | PK part, NN. |
| `start_time` | time | NN. |
| `end_time` | time | NN, CK later than `start_time`; a window must have positive length. |

The pair `(pro_id, work_date)` is the PK because the export has one daily window per professional. It prevents duplicate daily rows.

### `customers` — people who book services

| Column | Type | Rules and reason |
|---|---|---|
| `customer_id` | integer | PK, NN. |
| `full_name` | text | NN. |
| `phone` | varchar(20) | NN, UQ; text identifier, unique in the export. |
| `email` | text | NULL allowed, UQ; missing email is valid and non-empty emails are unique. PostgreSQL permits multiple NULLs in a unique column. |
| `city_id` | integer | FK → `cities.city_id`, NN, RESTRICT. |
| `plus_valid_until` | date | NULL allowed; NULL means no current Plus expiry date is recorded. |
| `created_at` | timestamptz | NN; preserve the offset in the export. |

### `bookings` — booked service jobs and their outcome

| Column | Type | Rules and reason |
|---|---|---|
| `booking_id` | integer | PK, NN. |
| `customer_id` | integer | FK → `customers.customer_id`, NN, RESTRICT. |
| `service_id` | integer | FK → `services.service_id`, NN, RESTRICT. |
| `pro_id` | integer | NULL allowed; FK → `professionals.pro_id`, RESTRICT. A booking may be unassigned, and customer-cancelled rows can also lack an assigned professional. |
| `city_id` | integer | FK → `cities.city_id`, NN, RESTRICT; stored on the booking to report its booked location. |
| `pincode` | varchar(10) | NN; text preserves postal-code formatting and leading zeroes. |
| `booked_at` | timestamptz | NN. |
| `scheduled_start` | timestamptz | NN. |
| `scheduled_end` | timestamptz | NN, CK later than `scheduled_start`. |
| `started_at` | timestamptz | NULL allowed; populated only for completed jobs in this export. |
| `completed_at` | timestamptz | NULL allowed; populated only for completed jobs in this export. |
| `status` | varchar(24) | NN, CK in (`REQUESTED`,`ASSIGNED`,`COMPLETED`,`NO_SHOW`,`CANCELLED_BY_PRO`,`CANCELLED_BY_CUSTOMER`). |
| `price` | numeric(10,2) | NN, CK >= 0. Exact charged service amount before discount. |
| `discount` | numeric(10,2) | NN, CK between 0 and `price`. |
| `cancellation_fee` | numeric(10,2) | NN, CK >= 0; zero means no fee. |
| `tip` | numeric(10,2) | NULL allowed, CK >= 0 when present; no tip is represented as NULL in the source. |
| `payment_method` | varchar(10) | NN, CK in (`UPI`,`CASH`,`CARD`,`WALLET`). |

### `reschedules` — changes to a booking's scheduled start

| Column | Type | Rules and reason |
|---|---|---|
| `reschedule_id` | integer | PK, NN; a booking can have more than one reschedule. |
| `booking_id` | integer | FK → `bookings.booking_id`, NN, RESTRICT. |
| `old_start` | timestamptz | NN. |
| `new_start` | timestamptz | NN, CK different from `old_start`; this must record a change. |
| `requested_by` | varchar(8) | NN, CK in (`CUSTOMER`,`PRO`). |
| `reason` | text | NN. |
| `created_at` | timestamptz | NN. |

### `reviews` — customer and professional ratings for a job

| Column | Type | Rules and reason |
|---|---|---|
| `booking_id` | integer | PK and FK → `bookings.booking_id`, RESTRICT; one review at most per booking, and the booking is the review's identity. |
| `rating_for_pro` | smallint | NN, CK 1–5. |
| `comment` | text | NULL allowed; many reviews have no written comment. |
| `rating_for_customer` | smallint | NULL allowed, CK 1–5 when present; a customer rating is optional. |
| `created_at` | timestamptz | NN. |

### `payouts` — weekly professional payment summaries

| Column | Type | Rules and reason |
|---|---|---|
| `payout_id` | integer | PK, NN. |
| `pro_id` | integer | FK → `professionals.pro_id`, NN, RESTRICT. |
| `week_start` | date | NN; must be a Monday (CK). |
| `jobs` | integer | NN, CK > 0. |
| `gross_earnings` | numeric(12,2) | NN, CK >= 0. |
| `commission` | numeric(12,2) | NN, CK between 0 and `gross_earnings`. |
| `net_payout` | numeric(12,2) | NN, CK equals `gross_earnings - commission`. |
| `status` | varchar(8) | NN, CK in (`PAID`,`PENDING`). |
| `paid_at` | timestamptz | NULL allowed; required for `PAID` and absent for `PENDING`. |

`(pro_id, week_start)` is also UNIQUE: at most one weekly payout summary exists for a professional, even though `payout_id` is the stable PK.

## Relationships and cardinality

- One city has many professionals and many customers; each professional/customer row points to one city (`cities` 1:N `professionals`, `cities` 1:N `customers`).
- One city can appear on many bookings; each booking records one city (`cities` 1:N `bookings`).
- One category has many services and many professional skill rows (`service_categories` 1:N `services`, `service_categories` 1:N `pro_skills`).
- Professionals and categories have an M:N relationship through `pro_skills`; the composite PK prevents the same professional-category pair being repeated.
- One professional has many availability rows, bookings, and payouts (`professionals` 1:N each). An individual availability row refers to one professional and date.
- One customer, service, and professional can each be associated with many bookings; each booking refers to one customer and one service, and may refer to zero or one professional (`customers` 1:N `bookings`; `services` 1:N `bookings`; `professionals` 1:N `bookings` with nullable booking side).
- One booking can have many reschedule events (`bookings` 1:N `reschedules`).
- A booking has zero or one review (`bookings` 1:0..1 `reviews`); the review PK is also its booking FK.
- One professional has many weekly payout rows; the professional/week pair is unique (`professionals` 1:N `payouts`).

## Why these keys and constraints

Integer source ids are the clearest stable primary keys for entity rows. The two natural composite keys reflect the real uniqueness of a professional's skill per category and availability per date. Reviews are one per booking, so using `booking_id` avoids an artificial second identifier. Payouts retain their explicit source id and additionally enforce one row per professional/week.

The rules below are meaningful checks that match the data and stop invalid values from entering the database:

1. All entity identifiers are PKs; PKs are automatically NOT NULL and unique.
2. All foreign-key columns point to a real parent; `pro_id` on bookings is nullable for unassigned jobs.
3. City/category names, service names, professional phones, and customer phones are unique.
4. Non-empty customer emails are unique; NULL email remains allowed.
5. Service duration is positive; base price is non-negative.
6. Professional gender and status are restricted to the exported codes; a present professional rating is 0–5.
7. Availability end time is after start time.
8. Booking status and payment method are restricted to known codes.
9. A booking's scheduled end is later than its scheduled start; `booked_at` is no later than `scheduled_start` in this export.
10. Booking price and discount are non-negative, and discount cannot exceed price.
11. A present tip is non-negative and appears only on completed bookings; a positive cancellation fee appears only on customer-cancelled bookings.
12. A booking is either completed with both actual timestamps or is not completed with neither timestamp, matching this export's lifecycle snapshot.
13. Reschedule actor is `CUSTOMER` or `PRO`, and the new start differs from the old start.
14. Review ratings, when present, are integers from 1 through 5.
15. Payout jobs are positive; amounts are non-negative; commission cannot exceed gross; net equals gross minus commission.
16. Payout week starts on Monday; payout status is `PAID` or `PENDING`; `paid_at` exists exactly for paid rows.

Primary keys and UNIQUE constraints create their usual PostgreSQL indexes. No workload-tuning indexes are part of this design.

## Data-quality findings from the CSVs

- Optional fields are genuinely absent, not empty strings: 11,920 of 40,000 customer emails; 32,869 `plus_valid_until` dates; 72 professional ratings; 6,142 booking professional ids; 22,308 pairs of booking start/completion timestamps; 124,473 tips; 38,142 review comments; 22,869 customer review ratings; and 1,080 payout `paid_at` values. The status and relationship context explains these nulls: for example, 84 `REQUESTED` bookings have no professional, and pending payouts have no paid time.
- The optional customer email and professional rating fields are NULLable. The review comment and customer rating are also optional. A missing tip is retained as NULL rather than converted to zero so the source meaning is preserved.
- The booking export has 12,123 customer cancellations; 6,058 of them have no professional. Query R13 uses `NOT IN` against the professional ids of customer-cancelled bookings. Since that subquery includes NULL, SQL's three-valued NULL logic makes the `NOT IN` predicate unknown for every active professional, so the query returns no rows. This is a query correctness issue exposed by the data; `NOT EXISTS` is the safe anti-join form.
- Every checked foreign-key reference resolved to a CSV parent row. Natural unique values listed above had no duplicates. Composite `(pro_id, category_id)` skills and `(pro_id, work_date)` availability keys had no duplicates; `(pro_id, week_start)` payouts had no duplicates; review booking ids were unique.
- Time and money checks in the table descriptions passed on all rows. All 27,015 payout weeks are Mondays and each net payout equals gross earnings minus commission. Each of the 76,539 review rows points to a completed booking.
- The availability file is a dated snapshot covering June–July 2026, not complete historical availability. Of the 7,137 assigned bookings whose professional/date had an availability row in that snapshot, 1,466 fell outside that listed time window. This is a cross-file consistency warning, not a row-level SQL CHECK violation: the exports do not establish whether the availability row was later changed or whether assignment data is inconsistent. Do not use an availability CHECK to reject these seed rows.

## Integrity checks from the CSVs

These checks were run against the extracted CSVs; the repository does not yet contain a schema to load into PostgreSQL.

| Check | Result |
|---|---|
| Foreign-key coverage across all 13 FK relationships listed above | 0 unmatched non-NULL references. |
| Duplicate composite identities for skills, daily availability, and professional/week payouts | 0 duplicates. |
| Booking schedule end after start, booking time no later than schedule, discount no greater than price, and fee/tip/status consistency | All 150,000 rows passed. |
| Payout week Monday, non-negative financial amounts, and net arithmetic | All 27,015 rows passed. |
| Reviews belong to completed bookings | All 76,539 reviews passed. |
| Professional availability versus booking slots on matching dates | 1,466 of 7,137 applicable assigned jobs sit outside the listed daily window; see the snapshot caveat above. |

## In plain terms

I kept the design simple: each table has one clear job, keys connect related rows, and a small set of checks catches common mistakes. The CSVs also contain missing values and some availability mismatches, so I have described those openly instead of hiding them behind complicated rules.
