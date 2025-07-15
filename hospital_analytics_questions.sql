-- Connect to database (MySQL only)
USE hospital_db;

-- OBJECTIVE 1: ENCOUNTERS OVERVIEW

-- a. How many total encounters occurred each year?
SELECT 
    YEAR(START) AS  year,
	COUNT(id) AS total_encounters
FROM 
   encounters
GROUP BY
   YEAR(START)
ORDER BY 
  year;
;

-- b. For each year, what percentage of all encounters belonged to each encounter class
-- (ambulatory, outpatient, wellness, urgent care, emergency, and inpatient)?
SELECT id,START, ENCOUNTERCLASS FROM encounters


WITH encounter_counts AS (
 SELECT 
        YEAR(start) AS year,
        encounterclass,
        COUNT(id) AS encounters
FROM 
    encounters
GROUP BY 
    YEAR(start),
	encounterclass
)
SELECT 
    year,
    encounterclass,
    encounters,
    (encounters * 100.0) / SUM(encounters) OVER (PARTITION BY year) AS all_encounters
FROM 
    encounter_counts
ORDER BY 
      year;


SELECT 
    YEAR(start) AS year,
    ROUND(COUNT(CASE WHEN encounterclass = 'ambulatory' THEN id END) * 100 / COUNT(id),1) AS ambulatory,
    ROUND(COUNT(CASE WHEN encounterclass = 'emergency' THEN id END) * 100 / COUNT(id),1) AS emergency,
    ROUND(COUNT(CASE WHEN encounterclass = 'inpatient' THEN id END) * 100 / COUNT(id),1) AS inpatient,
    ROUND(COUNT(CASE WHEN encounterclass = 'outpatient' THEN id END) * 100 / COUNT(id),1) AS outpatient,
    ROUND(COUNT(CASE WHEN encounterclass = 'urgentcare' THEN id END) * 100 / COUNT(id),1) AS urgentcare,
    ROUND(COUNT(CASE WHEN encounterclass = 'wellness' THEN id END) * 100 / COUNT(id),1) AS wellness
FROM encounters
GROUP BY YEAR(start)
ORDER BY year;



-- c. What percentage of encounters were over 24 hours versus under 24 hours?
SELECT
    COUNT(DATEDIFF(HOUR,START,STOP))
FROM 
   encounters
WHERE DATEDIFF(HOUR,START,STOP)>=24;

SELECT
    COUNT(DATEDIFF(HOUR,START,STOP))
FROM 
   encounters
WHERE DATEDIFF(HOUR,START,STOP)<24;

SELECT 
     CONCAT(SUM(CASE WHEN DATEDIFF(HOUR,START,STOP)>=24 THEN 1 ELSE 0 END)*100/COUNT(*), '%') AS over_24_hours,
	 CONCAT(SUM(CASE WHEN DATEDIFF(HOUR,START,STOP)<24 THEN 1 ELSE 0 END)*100/COUNT(*), '%') AS under_24_hours
FROM
    encounters;
-- OBJECTIVE 2: COST & COVERAGE INSIGHTS

-- a. How many encounters had zero payer coverage, and what percentage of total encounters does this represent?
select * from encounters;

SELECT 
   CONCAT(SUM(CASE WHEN PAYER_COVERAGE=0 THEN 1 ELSE 0 END)*100/COUNT(*),'%') AS zero_payer_Coverage
FROM 
   encounters;


-- b. What are the top 10 most frequent procedures performed and the average base cost for each?
select * from encounters;
select * from procedures;
SELECT
    TOP 10
    CODE,
	DESCRIPTION,
	COUNT(*) AS frequent_procedures,
	AVG(BASE_COST) AS average_base_Cost
FROM
     procedures
GROUP BY
    CODE,
    DESCRIPTION
ORDER BY
    frequent_procedures DESC;


-- c. What are the top 10 procedures with the highest average base cost and the number of times they were performed?

SELECT
    TOP 10
    CODE,
	DESCRIPTION,
	COUNT(*) AS frequent_procedures,
	AVG(BASE_COST) AS average_base_Cost
FROM
     procedures
GROUP BY
    CODE,
    DESCRIPTION
ORDER BY
    average_base_Cost DESC;

-- d. What is the average total claim cost for encounters, broken down by payer?
SELECT * FROM payers;
SELECT
   payers.NAME,
   ROUND(AVG(encounters.TOTAL_CLAIM_COST),2) AS average_claim_cost
FROM
  payers
LEFT JOIN 
  encounters
ON 
  payers.id=encounters.PAYER
GROUP BY
    payers.NAME
ORDER BY
    average_claim_cost DESC;
-- OBJECTIVE 3: PATIENT BEHAVIOR ANALYSIS

-- a. How many unique patients were admitted each quarter over time?
SELECT  
   DATEPART(YEAR,START) AS years,
   DATEPART(QUARTER,START) AS quarter_time,
   COUNT(DISTINCT PATIENT) AS total_patients
FROM
  encounters
GROUP BY
  DATEPART(QUARTER,START),
  DATEPART(YEAR,START)
ORDER BY
   quarter_time,
    years;
-- b. How many patients were readmitted within 30 days of a previous encounter?
 
 WITH readmitted_patients AS(
 SELECT
   PATIENT,
   START,
   STOP,
   LEAD(START) OVER(PARTITION BY PATIENT ORDER BY START) AS next_admitted_date
FROM
  encounters)
SELECT
   COUNT(DISTINCT PATIENT) AS num_patients
FROM 
   readmitted_patients
WHERE
   DATEDIFF(DAY,next_admitted_date,STOP)<30;


-- c. Which patients had the most readmissions?
WITH most_readmissions AS(
 SELECT
   PATIENT,
   START,
   STOP,
   LEAD(START) OVER(PARTITION BY PATIENT ORDER BY START) AS next_admitted_date
FROM
  encounters)
SELECT
   PATIENT,
   COUNT(*) AS num_readmissions
FROM 
   most_readmissions
GROUP BY 
  PATIENT
ORDER BY
   num_readmissions DESC;



   WITH most_readmissions AS (
    SELECT
        PATIENT,
        START,
        STOP,
        LEAD(START) OVER(PARTITION BY PATIENT ORDER BY START) AS next_admitted_date
    FROM
        encounters
),
valid_readmissions AS (
    SELECT
        PATIENT,
        START,
        STOP,
        next_admitted_date
    FROM
        most_readmissions
    WHERE 
        DATEDIFF(DAY, STOP, next_admitted_date) <= 30
),
readmission_counts AS (
    SELECT
        PATIENT,
        COUNT(*) AS num_readmissions
    FROM 
        valid_readmissions
    GROUP BY 
        PATIENT
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY num_readmissions DESC) AS rank_pos
    FROM readmission_counts
)
SELECT *
FROM ranked
WHERE rank_pos = 5;

