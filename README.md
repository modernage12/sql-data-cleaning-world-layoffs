# World Layoffs: SQL Data Cleaning

Progetto SQL dedicato alla pulizia e alla standardizzazione di un dataset reale sui licenziamenti globali (dal 2021 in poi). L'obiettivo è trasformare i dati grezzi (raw data) in un set di dati accurato e pronto per la fase di Exploratory Data Analysis (EDA).

La repository contiene sia il file iniziale (`layoffs.csv`) sia la versione finale pulita per il confronto diretto.

---

## Struttura del Progetto

Il processo si articola in 4 fasi principali, eseguite su una tabella di *staging* per preservare l'integrità dei dati originali:

1. **Rimozione dei duplicati:** Identificazione e cancellazione dei record ripetuti.
2. **Standardizzazione:** Correzione di refusi, spazi extra e formati strutturali.
3. **Gestione valori nulli/vuoti:** Recupero logico dei dati mancanti o eliminazione dei record irrecuperabili.
4. **Ottimizzazione:** Rimozione delle colonne e delle righe non utili all'analisi.

---

## Pipeline di Pulizia (Query Principali)

### 1. Creazione Tabella Staging

```sql
CREATE TABLE layoffs_staging
SELECT * FROM layoffs;

```

### 2. Rimozione Duplicati

Senza un ID univoco, i duplicati sono stati individuati tramite `ROW_NUMBER()` e `PARTITION BY` su tutte le colonne. I record con `row_num > 1` sono stati inseriti in una seconda tabella d'appoggio (`layoffs_staging2`) ed eliminati.

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

### 3. Standardizzazione dei Testi e delle Date

* Rimozione spazi extra: `SET company = TRIM(company);`
* Accorpamento categorie simili (es. da 'Cryptocurrency' a 'Crypto'): `SET industry = 'Crypto' WHERE industry LIKE 'Crypto%';`
* Conversione della colonna data da testo (`TEXT`) a tipo appropriato (`DATE`):

```sql
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

```

### 4. Gestione dei Valori Mancanti

I valori vuoti (`''`) sono stati convertiti in `NULL`. Per i campi recuperabili (come il settore di Airbnb), è stato applicato un **Self JOIN** per copiare il dato da altre righe della stessa azienda.

```sql
UPDATE layoffs_staging2 l1
JOIN layoffs_staging2 l2
    ON l1.company = l2.company
SET l1.industry = l2.industry
WHERE l1.industry IS NULL 
AND l2.industry IS NOT NULL;

```

I record con valori nulli contemporanei sia in `total_laid_off` che in `percentage_laid_off` sono stati eliminati perché inutilizzabili per l'analisi.

---

## Funzioni SQL Utilizzate

| Strumento | Utilizzo |
| --- | --- |
| `ROW_NUMBER() OVER()` | Assegnazione di un indice progressivo per gruppo di righe uguali |
| `WITH ... AS` | Creazione di CTE (tabelle temporanee) per l'analisi dei duplicati |
| `TRIM()` | Eliminazione degli spazi bianchi superflui |
| `STR_TO_DATE()` | Conversione di stringhe di testo in date valide |
| `ALTER TABLE` | Modifica strutturale dei tipi di dato e rimozione colonne |
| `Self JOIN` | Associazione della tabella con se stessa per popolare i valori NULL |

---

## TL;DR

Il progetto applica una pipeline di data cleaning in SQL su un dataset di licenziamenti globali. Tramite Window Functions, CTE e Self Join, i dati grezzi sono stati isolati, standardizzati nei formati (testi e date) e ripuliti da record duplicati o incompleti, il tutto operando su una tabella di staging per non intaccare la sorgente originale.
