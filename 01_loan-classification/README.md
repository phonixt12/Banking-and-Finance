# 📊 Loan Classification Report

## Overview
Classify loan contracts into debt groups
based on overdue days, following SBV standards.

## Debt Group Standard
| Group | Name | Overdue Days |
|-------|------|-------------|
| 1 | Standard | Under 10 days |
| 2 | Watch | Up to 90 days |
| 3 | Substandard | 91–180 days |
| 4 | Doubtful | 181–360 days |
| 5 | Loss | Over 360 days |

## Data Source
- Internal bank database (MSSQL)

## Tools
- SQL Server (T-SQL)
- Power BI

## How to Run
1. Run all SQL in Create table folder for creating database
  -  `sql/01_Credit_Plan.sql` 
  -  `sql/02_Debt_payment.sql`
  -  `sql/03_Payment_Plan.sql`
  
2. Run `sql/02_classification.sql`
3. Open `powerbi/dashboard.pbix`