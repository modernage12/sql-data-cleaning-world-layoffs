# World Layoffs: SQL Data Cleaning

An SQL project focused on cleaning and standardizing a real-world dataset on global layoffs (from 2021 onwards). The objective is to transform raw data into an accurate dataset ready for Exploratory Data Analysis (EDA).

The repository contains both the initial file (`layoffs.csv`) and the final cleaned version for direct comparison.

---

## Project Structure

The process consists of 4 main phases, executed on a staging table to preserve the integrity of the original data:

1. **Duplicate removal:** Identifying and deleting repeated records.
2. **Standardization:** Correcting typos, extra spaces, and structural formats.
3. **Null/blank value management:** Logical recovery of missing data or removal of unrecoverable records.
4. **Optimization:** Removing columns and rows that are not useful for the analysis.

---

## Cleaning Pipeline (Main Queries)

### 1. Creating the Staging Table

```sql
CREATE TABLE layoffs_staging
SELECT * FROM layoffs;

```

### 2. Duplicate Removal

Without a unique ID, duplicates were identified using `ROW_NUMBER()` and `PARTITION BY` across all columns. Records with `row_num > 1` were inserted into a second staging table (`layoffs_staging2`) and then deleted.

```sql
WITH duplicates_cte AS (
    SELECT *, 
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, `date`, stage, country, funds_raised_millions
    ) AS row_num
    FROM layoffs_staging
)
SELECT * FROM duplicates_cte WHERE row_num > 1;

```

### 3. Text and Date Standardization

* Removing extra spaces: `SET company = TRIM(company);`
* Grouping similar categories (e.g., from 'Cryptocurrency' to 'Crypto'): `SET industry = 'Crypto' WHERE industry LIKE 'Crypto%';`
* Converting the date column from text (`TEXT`) to the appropriate type (`DATE`):

```sql
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

```

### 4. Handling Missing Values

Blank values (`''`) were converted to `NULL`. For fields that could be populated (such as Airbnb's industry), a Self JOIN was applied to copy the data from other rows of the same company.

```sql
UPDATE layoffs_staging2 l1
JOIN layoffs_staging2 l2
    ON l1.company = l2.company
SET l1.industry = l2.industry
WHERE l1.industry IS NULL 
AND l2.industry IS NOT NULL;

```

Records with concurrent null values in both `total_laid_off` and `percentage_laid_off` were deleted because they were unusable for analysis.

---

## SQL Functions Used

| Tool | Usage |
| --- | --- |
| `ROW_NUMBER() OVER()` | Assigns a progressive index for groups of identical rows |
| `WITH ... AS` | Creates CTEs (temporary tables) for duplicate analysis |
| `TRIM()` | Removes superfluous white spaces |
| `STR_TO_DATE()` | Converts text strings into valid dates |
| `ALTER TABLE` | Structural modification of data types and column removal |
| `Self JOIN` | Joins the table with itself to populate NULL values |

---

## TL;DR

This project applies an SQL data cleaning pipeline to a global layoffs dataset. Using Window Functions, CTEs, and Self Joins, raw data was isolated, standardized in format (text and dates), and cleaned of duplicate or incomplete records, all while operating on a staging table to preserve the original source.
