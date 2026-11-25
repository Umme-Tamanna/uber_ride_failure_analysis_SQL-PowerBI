# Uber NCR Ride Bookings 2024: Why 38% of Bookings Fail

A SQL and Power BI case study on ride booking failures in Delhi NCR: how big the problem is, what drives it, what does not, and what to investigate next.

Tools: MySQL (data audit, cleaning, analysis) · Power BI and DAX (dashboard) · PowerPoint (recommendations)

Dashboard

Business problem

Only 62% of ride bookings end in a completed ride. Why are so many bookings failing, and where should the business focus to fix it?

The project answers four questions:

How big is the problem?
Who or what causes it?
When and where does it happen?
How much revenue is at stake?
Key findings
#	Finding	Evidence
1	38% of bookings fail	57,000 of 150,000 bookings: 27,000 cancelled by driver, 10,500 cancelled by customer, 10,500 no driver found, 9,000 incomplete
2	Drivers initiate the largest share of failures	27,000 driver cancellations = 47% of failures. Adding 4,630 customers who cancelled citing the driver ("driver not moving towards pickup", "driver asked to cancel") brings driver involvement to about 55% (31,630 of 57,000)
3	Long waits end in customer cancellation	All 3,521 bookings with a 15+ minute wait were cancelled by the customer. Customer cancellations by wait band: 0.1% (0-5 min), 5.9% (5-10), 7.7% (10-15), 100% (15+)
4	The failure rate is systemic, not situational	Failure rate stays between 36% and 39% in every hour of the day while demand swings about 9x (peak 12,397 bookings at 18:00 vs about 1,300 overnight). Vehicle type, weekday, month and area show no real difference either
5	About 24.4M in revenue is unrealised (estimate)	48,000 cancelled or unfulfilled bookings x average completed fare of 508.2. Completed-ride revenue is 47.26M

Caveat on finding 2: cancellation reasons are self-reported by whoever cancelled. 75% of driver-stated reasons (20,274 of 27,000) blame the customer ("customer related issue", "customer sick/coughing", "more than permitted people"), which cannot be verified from this data.

Dashboard

A single page, structured as problem, causes, and what is not a cause:

Visual	What it shows
KPI cards	Total bookings, completion rate, failure rate, revenue, estimated lost revenue
Donut	Outcome mix of all bookings
100% stacked bar	Booking outcome by driver wait-time band (the 15+ minute row is entirely customer-cancelled)
Bar chart	Failures grouped by cause: driver cancelled, customer cancelled citing the driver, other customer reasons, no driver found, incomplete
Column and line chart	Bookings by hour of day vs failure rate (secondary axis), showing demand changes but the failure rate does not
Slicer	Vehicle Type, to confirm the pattern holds for every vehicle

Power BI file: powerbi/uber_analysis.pbix

Recommendations

These are hypotheses to test, not proven fixes. Slides: docs/uber_failure_recommendations.pptx

Problem	Recommended action
Drivers cancel the most bookings	Audit driver cancellation reasons against trip logs; test incentives or accountability for accepted rides
Long waits always end in customer cancellation	Find out why 15+ minute ETAs still reach customers, and which areas and hours they come from
Failure rate is flat everywhere	Target driver cancellations and long waits, not peak-hour or vehicle-specific fixes

Data needed next: driver supply by area and hour, to explain the 10,500 "no driver found" bookings (18% of failures), which nothing in this dataset explains.

Data
Source: Kaggle: NCR Ride Bookings (simulated ride-hailing data)
Size: 150,000 bookings, 21 columns, 1 Jan to 30 Dec 2024
Key columns: Booking Status, Vehicle Type, Pickup Location, Drop Location, Avg VTAT (minutes for the vehicle to reach the pickup point), Avg CTAT (trip duration in minutes), Booking Value, Ride Distance, cancellation and incomplete-ride reasons, ratings, Payment Method
Revenue definition: completed rides only. Currency is not stated in the dataset
Approach
1. Staging

The raw table ncr_ride_bookings is left untouched. All work happens in a copy, uber_rides_staging.

2. Data quality audit and cleaning
Check	Finding	Action
Blank or NULL Booking IDs	Checked	Rows removed if any
Fully duplicated rows	None	Nothing removed
Repeated Booking IDs	1,233 IDs reused across different rides (different customers, dates, values)	All rows kept; Booking ID is not used as a key
Data types	Imported as text	Date converted to DATE, Time to TIME, numeric columns to DECIMAL/INT
Text "nulls"	Empty strings	Converted to SQL NULL, not replaced
Structural blanks	48,000 rides have no fare or payment method, 10,500 have no wait time, 57,000 have no driver rating	Left as NULL: cancelled rides have no fare or rating by nature, so filling them in would be wrong
3. SQL analysis

Queries are in sql/uber_ride_analysis.sql, covering:

Headline KPIs: completion rate, failure rate, revenue, average fare
Outcome mix of all bookings
Failure rate by vehicle type
Bookings and failure rate by hour of day
Cancellation reasons by customer and by driver
Failure rate by pickup area (with a minimum-volume filter)
Payment mix of completed rides
Monthly trend with month-over-month change (CTE and LAG())
Wait-time band vs booking outcome
Estimated revenue lost (failed bookings x average completed fare)
