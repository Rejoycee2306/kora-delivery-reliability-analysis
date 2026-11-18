# Kora Workplace Supply Ltd — Delivery Reliability Analysis

## 📌 Project Overview
This project investigates the delivery reliability and fulfillment performance of **Kora Workplace Supply Ltd**, a fictional Nigerian supplier of workplace technology, furniture, and business supplies. Working on behalf of Kora's Operations Manager, this analysis assesses consignment execution across 2025 (with a data snapshot cutoff of **December 31, 2025**) to pinpoint operational bottlenecks, financial leakage from delivery failures, and carrier versus branch performance discrepancies.

---

## 🗄️ Dataset Overview
The analysis is primarily built around the **deliveries** and **orders** tables from the Kora 2025 database extract, with `deliveries` serving as the primary analytical table.

* **Database Schema Relationship:** The `orders` table acts as the parent table, linked **one-to-many** to the child `deliveries` table via `order_id` (meaning a single customer order can be split into multiple delivery consignments).
* **Table Structures:**
  * **`deliveries` Table (Primary):** Contains one row per delivery consignment (6,408 total records). Key fields include:
    * `delivery_id`: Unique primary key for each consignment.
    * `order_id`: Foreign key linking back to the parent order.
    * `branch_id`: Distribution center handling the dispatch.
    * `carrier`: Logistics provider (*In-house fleet*, *Northline Logistics*, or *Swift Parcel*).
    * `promised_delivery_date`, `dispatch_date`, & `delivered_date`: Milestone timestamps used to evaluate SLA adherence and transit duration.
    * `status`: Current fulfillment state (*Delivered*, *Failed*, *In transit*, or *Scheduled*).
    * `shipping_cost_ngn`: Recorded freight cost in Nigerian Naira (NGN).
    * `exception_reason`: Operational tag explaining delays or failures (e.g., *Capacity delay*, *Customer unavailable*).
  * **`orders` Table (Supporting):** Contains one row per customer order placed in 2025 (6,001 total records). Key fields include `order_id`, `order_date`, `customer_id`, `branch_id`, `channel`, `promised_delivery_date`, `status`, and `cancellation_reason`.
* **Scope & Control Totals:** The extract tracks orders placed between January 1 and December 31, 2025, with consignment milestones recorded through December 31, 2025.
---

## 🛠️ Methodology & Data Quality Checks
* **Tools Used:** **MySQL** for data extraction, joining, cleaning, and metric calculations; **Power BI** for visual reporting.
* **Data Cleaning & Validation:**
  * **Missing Delivery Dates:** Confined strictly to non-delivered statuses (*Failed*, *In transit*, *Scheduled*), signifying parcels that never arrived, are active, or have not yet shipped.
  * **Zero Shipping Costs:** 65 *Scheduled* consignments recorded shipping costs of `0.00`, interpreted as unbilled/not-yet-recorded costs rather than free delivery.
  * **Integrity & Deduplication:** Row counts and unique primary keys matched guide expectations. Potential duplicate orders were checked and confirmed as distinct orders with unique line values.
  * **Exception Reason Audit:** Flagged 1,779 late delivered consignments that lacked an exception reason, identifying data-logging gaps for future operational audits.

---

## 📊 Key Findings & Insights

1. **Overall Fulfillment & Volume Split:** 
   * Out of **6,408 total consignments**, **6,137 (95.8%)** were successfully delivered. 
   * **₦2.51M** was tied up in uncompleted work, comprising **125 failed deliveries** (**₦1.48M** sunk loss) and **146 unresolved consignments** (of which **23, or 15.75%, were already overdue** at the December 31 snapshot).
2. **On-Time Delivery (OTD) Performance:**
   * The overall OTD rate among delivered consignments stands at **56.1%**. 
   * **Promised Window Mismatch:** Promised delivery windows average **2.8 days** while actual transit averages **4.4 days**, indicating that baseline SLA targets across the network are overly tight.
3. **Branch vs. Carrier Root Cause Analysis:**
   * Third-party and in-house carriers perform almost identically (**56%–57% OTD**). Because carriers show uniform performance across branches, delivery failures sit with internal branch operations rather than carrier performance.
   * **Branch BR3 Outlier:** BR3 is a severe operational bottleneck, achieving only **39.7% OTD** compared to **57.7%** for all other branches combined. All 10 of the latest delayed deliveries across the company (ranging up to **21 days late**) originated from BR3. BR3 recorded **164 Capacity-delay consignments** where parcels took an average of **13.3 days** in transit against a **3.1-day** promise.
4. **Financial Unit Economics & Branch BR1 Last-Mile Leakage:**
   * Total recorded shipping cost is **₦79.93M**. Cost per dispatched consignment is **₦12.60k** versus **₦13.02k** per delivered consignment; the **₦422.99 gap** represents the financial penalty of failed and in-transit parcels.
   * **Branch BR1 Dynamics:** BR1 handles **56% of total company volume** and absorbed **82 of the 125 failed deliveries** (totaling **₦902.6k**, all labeled under `"Customer unavailable"`), highlighting a last-mile communication gap rather than a warehouse failure.

---

## 🖼️ Dashboard Preview
The Power BI dashboard translates these findings into 4 core KPIs and 5 visual components:

![Kora Delivery Reliability Dashboard](Kora%202025%20dashboard.png)

* **KPI Cards:** Total Consignments (6,408), On-time Delivery Rate (56%), Total Shipping Cost (₦79.93M), and Overdue Backlog (23 / 16% of unresolved).
* **Visualizations:** Cost per delivered consignment by branch, unresolved consignments relative to snapshot date, average delay by status, monthly OTD trends through 2025, and OTD rates broken down by branch and carrier.

---

## 💡 Strategic Recommendations

1. **Investigate and Rectify Pre-Dispatch Bottlenecks at Branch BR3:**
   * *Action:* Audit warehouse workflows, carrier handover processes, fleet capacity, and seasonal volume handling at BR3 to resolve the systemic root cause behind the 164 `Capacity delay` incidents and multi-week delivery lags.
2. **Pilot Pre-Dispatch Customer Confirmation at Branch BR1:**
   * *Action:* Introduce an automated SMS or phone verification step 24 hours prior to courier dispatch from BR1 to confirm recipient availability, directly tackling the `"Customer unavailable"` failure trend and measuring failure rates before and after.
3. **Recalibrate Baseline SLA Promised Windows:**
   * *Action:* Review the operational gap between the 2.8-day average promised window and the 4.4-day actual transit reality, adjusting customer-facing delivery promises to match true logistics capabilities.

---

## ⚠️ Limitations & Proposed Data Requests
* **Limitations:** 
  * The dataset is a static point-in-time snapshot (December 31, 2025), meaning unresolved consignments may have changed status afterward.
  * The exception reason `"Capacity delay"` lacks an explicit definition, preventing confirmation of whether the bottleneck is warehouse staffing, fleet size, or carrier capacity.
  * Small branch/carrier cell sizes among unresolved orders (146 total, 23 overdue) limit granular ranking.
  * Missing weekly volume, staffing, route distance, and product/customer mix metrics prevent deeper causal profiling.
* **Data to Request:** Monthly staffing and volume breakdowns for BR3, clear definitions for operational exception tags, and delivery-location coordinate tracking for BR1 failures.

---

## 📂 Repository Structure
```text
├── data/                  # Source CSV/database extracts (Kora 2025 dataset)
├── sql/                   # MySQL script containing data cleaning & query solutions
├── dashboard/             # Power BI report file (.pbix) and dashboard exports (.png)
└── README.md              # Project documentation and summary of findings
```

*Dataset credit: Fictional, synthetic training dataset provided by CadencePlus Solutions™.*
