-- ============================================================
-- DATA CLEANING PROJECT - Layoffs Dataset
-- Tool: MySQL Workbench
-- Dataset: layoffs.csv
-- ============================================================
-- STEPS:
--   1. Setup: creazione tabella staging
--   2. Rimozione duplicati
--   3. Standardizzazione valori
--   4. Gestione NULL e blank values
--   5. Rimozione colonne inutili
-- ============================================================
-- REGOLA: non lavorare mai sui raw data originali.
-- Tutto il lavoro avviene su layoffs_staging / layoffs_staging2.
-- ============================================================


-- ============================================================
-- SETUP: Creazione tabella staging
-- ============================================================

-- CREATE TABLE IF NOT EXISTS crea la tabella solo se non esiste gia,
-- evitando errori se esegui lo script piu volte.
-- SELECT * FROM layoffs copia struttura e dati della tabella originale.
-- La tabella staging e la nostra copia di lavoro: mai toccare i raw data.
CREATE TABLE IF NOT EXISTS layoffs_staging
SELECT *
FROM layoffs;


-- ============================================================
-- STEP 1: RIMOZIONE DUPLICATI
-- ============================================================

-- Check iniziale: visualizzo le righe con numero progressivo per gruppo.
-- ROW_NUMBER() OVER(PARTITION BY) assegna il numero all'interno di ogni
-- gruppo di righe con valori identici su tutte le colonne chiave.
-- row_num = 1 -> riga unica nel gruppo
-- row_num > 1 -> duplicato
SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off,
                     percentage_laid_off, `date`, stage, country,
                     funds_raised_millions
    ) AS row_num
FROM layoffs_staging;

-- CTE per filtrare e visualizzare solo i duplicati (row_num > 1).
-- Non posso usare WHERE row_num > 1 direttamente sulla query precedente
-- perche row_num e un alias creato nello stesso SELECT e non ancora
-- disponibile nel WHERE della stessa query.
-- La CTE crea una "tabella temporanea" interrogabile solo per la durata
-- della query.
WITH duplicates AS
(
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY company, location, industry, total_laid_off,
                         percentage_laid_off, `date`, stage, country,
                         funds_raised_millions
        ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicates
WHERE row_num > 1;

-- Check manuale di verifica su un caso specifico identificato come duplicato.
-- Se tutti i campi sono uguali su piu righe, e un duplicato reale.
SELECT *
FROM layoffs_staging
WHERE company = 'Wildlife Studios';

-- Non si puo fare DELETE direttamente su una CTE.
-- Soluzione: creo una seconda tabella staging con la colonna row_num
-- gia inclusa, cosi posso fare DELETE direttamente sulla tabella.
CREATE TABLE IF NOT EXISTS layoffs_staging2
SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off,
                     percentage_laid_off, `date`, stage, country,
                     funds_raised_millions
    ) AS row_num
FROM layoffs_staging;

-- Elimino i duplicati: row_num > 1 identifica tutte le occorrenze
-- successive alla prima. Le righe con row_num = 1 vengono mantenute.
DELETE
FROM layoffs_staging2
WHERE row_num > 1;


-- ============================================================
-- STEP 2: STANDARDIZZAZIONE
-- ============================================================

-- ---- TRIM: Rimozione spazi extra ----

-- Check visivo: confronto il valore originale con quello dopo il TRIM.
SELECT company, TRIM(company)
FROM layoffs_staging2;

-- Applico il TRIM: rimuove gli spazi iniziali e finali.
-- Es.: '  Airbnb  ' diventa 'Airbnb'.
-- Senza WHERE si aggiornano tutte le righe della colonna.
UPDATE layoffs_staging2
SET company = TRIM(company);

-- ---- INDUSTRY: Valori simili scritti diversamente ----

-- Check panoramica valori unici.
-- DISTINCT mostra tutte le varianti presenti: 'Crypto', 'Crypto Currency',
-- 'CryptoCurrency' sono lo stesso settore scritto in modi diversi.
SELECT DISTINCT(industry)
FROM layoffs_staging2
ORDER BY industry ASC;

-- Unifico tutte le varianti sotto un unico valore standardizzato.
-- LIKE 'Crypto%' cattura qualsiasi stringa che inizia con 'Crypto'.
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- ---- COUNTRY: Errori di formattazione ----

-- Check panoramica valori unici.
-- Es.: 'United States.' e 'United States' sono lo stesso paese,
-- il punto finale e un errore di formattazione.
SELECT DISTINCT(country)
FROM layoffs_staging2
ORDER BY country ASC;

-- Unifico le varianti di 'United States'.
-- LIKE 'United States%' cattura anche 'United States.'.
UPDATE layoffs_staging2
SET country = 'United States'
WHERE country LIKE 'United States%';

-- ---- DATE: Conversione formato data ----

-- Check visivo della conversione prima di applicarla.
-- STR_TO_DATE(colonna, formato) converte una stringa in tipo DATE.
-- Il formato deve rispecchiare come e scritta la data nella stringa originale.
-- %m = mese (con zero iniziale), %d = giorno, %Y = anno a 4 cifre.
-- Es.: '3/15/2023' con formato '%m/%d/%Y' diventa '2023-03-15'.
-- NOTA: 'date' e una parola riservata in MySQL. Va scritto tra backtick `date`
-- in ogni query che la referenzia, altrimenti MySQL genera un syntax error.
SELECT `date`, STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

-- Applico la conversione aggiornando la colonna.
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- STR_TO_DATE aggiorna il valore ma non cambia il tipo della colonna
-- nel database: la colonna e ancora di tipo TEXT.
-- ALTER TABLE modifica la struttura della tabella (non i dati).
-- MODIFY COLUMN cambia il tipo di dato della colonna.
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- ---- Re-check duplicati dopo la standardizzazione ----

-- Dopo la standardizzazione e buona pratica ripetere il check dei duplicati.
-- Valori prima diversi (es. 'Crypto' e 'CryptoCurrency') ora sono identici
-- e potrebbero aver creato nuovi duplicati non rilevati nella prima passata.
-- Uso new_row_num come alias per evitare conflitti con la colonna row_num
-- gia presente in layoffs_staging2.
WITH duplicates AS
(
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY company, location, industry, total_laid_off,
                         percentage_laid_off, `date`, stage, country,
                         funds_raised_millions
        ) AS new_row_num
    FROM layoffs_staging2
)
SELECT *
FROM duplicates
WHERE new_row_num > 1;


-- ============================================================
-- STEP 3: GESTIONE NULL E BLANK VALUES
-- ============================================================

-- ---- Check NULL e blank ----

-- IS NULL controlla i valori NULL.
-- = '' controlla le stringhe vuote (blank).
-- Sono due cose diverse in SQL: NULL e assenza di valore, '' e stringa vuota.
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL OR industry = '';

-- Verifico se le aziende con industry NULL hanno altre righe con il valore
-- compilato, da cui potrei recuperarlo.
-- Es.: se Airbnb ha una riga con industry = 'Travel' e un'altra con NULL,
-- posso recuperare il valore dalla riga che ce l'ha.
SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';

-- ---- Normalizzazione blank -> NULL ----

-- Converto tutti i blank in NULL prima del self JOIN.
-- Piu semplice lavorare con un solo tipo di valore mancante.
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- ---- Self JOIN: Recupero valori dalla stessa tabella ----

-- Un self JOIN e un JOIN della tabella con se stessa.
-- l1 e l2 sono alias per distinguere le due "copie" della stessa tabella.
-- Collego le righe tramite company: ogni riga di l1 si unisce alle righe
-- di l2 che hanno lo stesso nome azienda.
-- l1.industry IS NULL     -> la riga con il valore mancante
-- l2.industry IS NOT NULL -> la riga della stessa azienda con il valore
-- Check prima di modificare:
SELECT *
FROM layoffs_staging2 l1
JOIN layoffs_staging2 l2
    ON l1.company = l2.company
WHERE l1.industry IS NULL
  AND l2.industry IS NOT NULL;

-- Applico l'aggiornamento: riempio i NULL di l1 con i valori di l2.
-- UPDATE con JOIN: prima si scrive JOIN, poi SET.
UPDATE layoffs_staging2 l1
JOIN layoffs_staging2 l2
    ON l1.company = l2.company
SET l1.industry = l2.industry
WHERE l1.industry IS NULL
  AND l2.industry IS NOT NULL;

-- ---- Eliminazione righe irrecuperabili ----

-- Alcune righe rimangono con NULL anche dopo il self JOIN.
-- Se il valore non puo essere recuperato in nessun modo, la riga va eliminata.
DELETE FROM layoffs_staging2
WHERE company = "Bally's Interactive";

-- Alcune colonne sono cosi centrali per l'analisi che senza i loro valori
-- la riga non ha utilita analitica.
-- Se total_laid_off E percentage_laid_off sono entrambi NULL,
-- la riga non contiene informazioni utili sui licenziamenti.
-- NOTA: l'operatore corretto e AND (entrambi NULL), non OR (almeno uno NULL).
-- Il cheatsheet riportava OR, ma e un refuso: con OR si eliminerebbero
-- righe che hanno ancora un dato parzialmente utile.

-- Check prima di eliminare:
SELECT *
FROM layoffs_staging2
WHERE (total_laid_off IS NULL OR total_laid_off = '')
  AND (percentage_laid_off IS NULL OR percentage_laid_off = '');

-- Eliminazione righe dove ENTRAMBE le colonne chiave sono NULL o blank.
DELETE
FROM layoffs_staging2
WHERE (total_laid_off IS NULL OR total_laid_off = '')
  AND (percentage_laid_off IS NULL OR percentage_laid_off = '');


-- ============================================================
-- STEP 4: RIMOZIONE COLONNE INUTILI
-- ============================================================

-- ALTER TABLE DROP COLUMN elimina una colonna dalla struttura della tabella.
-- E un'operazione permanente sulla struttura, per questo si lavora sempre
-- sulla staging e non sui raw data.
-- Rimuoviamo row_num: e stata creata da noi per identificare i duplicati,
-- non fa parte dei dati originali e non serve all'analisi.
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- ============================================================
-- CHECK FINALE
-- ============================================================

SELECT *
FROM layoffs_staging2;