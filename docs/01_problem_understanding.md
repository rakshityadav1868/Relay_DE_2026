# Phase 1: Problem Understanding

This document breaks down the eight main problems reported across Urban Company's database system, identifying what the business needs, who is affected, how each problem is classified, and our core assumptions.

---

### Problem Breakdown (P1 – P8)

#### P1: Slow Service Menu and Time Slot Selection
- **What the business needs:** When a customer wants to book a service, the app must quickly show active services and let them choose a time slot. To suggest valid slots, the system needs to instantly check whether a professional is qualified for the category, is marked available for that day, and does not already have an overlapping booking.
- **Stakeholder affected:** Customer
- **Classification:** Customer-facing / real-time

#### P2: Delays in Booking Lookups and Customer Details
- **What the business needs:** Customers want to open the app and see their upcoming appointments immediately. Similarly, when a customer calls support, agents need to find their account and booking history by phone number without making the caller wait on hold.
- **Stakeholder affected:** Customer, Support
- **Classification:** Customer-facing / real-time

#### P3: Partner App Lag in the Field
- **What the business needs:** Service professionals rely on their mobile phones throughout the day to view today's assigned jobs, mark services as complete, record tips, and check their weekly earnings. These actions must be fast and responsive even on mobile networks.
- **Stakeholder affected:** Service professional
- **Classification:** Customer-facing / real-time

#### P4: Sluggish Dispatch for Unassigned Bookings
- **What the business needs:** Dispatchers need an instant view of all unassigned bookings that are scheduled to start soon so they can assign them to available professionals before customers are left waiting.
- **Stakeholder affected:** Dispatch / Operations
- **Classification:** Customer-facing / real-time

#### P5: Partner Rewards List Always Empty
- **What the business needs:** The partner success team wants to identify top-performing, reliable professionals who have never had a job cancelled by a customer so they can reward them. The query currently returns zero results due to an issue with how cancellations and NULL values are handled in the database.
- **Stakeholder affected:** Service professional, Dispatch / Operations
- **Classification:** Reporting / analytics

#### P6: Quality and Compliance Reports Timing Out
- **What the business needs:** The quality team needs regular reports on service standards: identifying professionals with high no-show rates, tracking jobs that started late, filtering poor customer reviews, and catching cases where a professional performed a job they were not trained or certified for.
- **Stakeholder affected:** Quality team
- **Classification:** Reporting / analytics

#### P7: Slow Financial Payouts and Revenue Reports
- **What the business needs:** The finance team needs to process weekly payouts for professionals on time, calculate gross merchandise value (GMV), track savings given to UC Plus members, and account for cancellation fees collected.
- **Stakeholder affected:** Finance, UC Plus team
- **Classification:** Reporting / analytics

#### P8: Sluggish Long-Term Planning and Capacity Reports
- **What the business needs:** Operations and expansion teams need aggregate data on peak booking hours, high-demand pincodes, repeat customer retention, and professional utilization rates across cities to plan future hiring and expansion as order volume grows 20x.
- **Stakeholder affected:** City expansion, Dispatch / Operations
- **Classification:** Reporting / analytics

---

### Key Assumptions
1. **Response Time Priorities:** Real-time customer and partner app queries must respond in milliseconds so users do not experience lag, whereas internal reporting queries can take a few seconds because they run periodically.
2. **Data Consistency:** Completed bookings, assigned professionals, and logged reviews represent verified historical events that should not be altered.
3. **Availability and Overlaps:** A service professional can only take on one job at any given time slot, and that slot must fall entirely within their declared working hours for that day.
4. **Skills and Eligibility:** Professionals can only be assigned to jobs belonging to categories they are certified in.
5. **Scale Expectations:** The database must continue to perform reliably when data volume increases 20-fold from 150,000 bookings to roughly 3 million bookings.
