CREATE DATABASE PrescriptionsDB;

USE PrescriptionsDB

SELECT *
FROM Drugs;

SELECT *
FROM Medical_Practice;

SELECT *
FROM Prescriptions;

SELECT *
FROM [Prescription Summary];


ALTER TABLE Prescriptions
ADD CONSTRAINT FK_Prescriptions_Practice 
        FOREIGN KEY (PRACTICE_CODE) REFERENCES Medical_Practice(PRACTICE_CODE),
    CONSTRAINT FK_Prescriptions_Drug 
        FOREIGN KEY (BNF_CODE) REFERENCES Drugs(BNF_CODE),
    CONSTRAINT CHK_Prescriptions_Quantity CHECK (QUANTITY > 0),
    CONSTRAINT CHK_Prescriptions_Items CHECK (ITEMS > 0),
    CONSTRAINT CHK_Prescriptions_Cost CHECK (ACTUAL_COST >= 0);


ALTER TABLE [Prescription Summary]
ADD SummaryID INT IDENTITY(1,1),
CONSTRAINT PK_PrescriptionSummary PRIMARY KEY (SummaryID),
    CONSTRAINT FK_PrescriptionsSummary_Practice FOREIGN KEY (PRACTICE_CODE) REFERENCES Medical_Practice(PRACTICE_CODE),
    CONSTRAINT CHK_PrescriptionsSummary_Items CHECK (TOTAL_ITEMS > 0),
    CONSTRAINT CHK_PrescriptionsSummary_Cost CHECK (TOTAL_COST >= 0);



-- VERIFICATION QUERIES
-- Test 1: Record Counts
SELECT 'Medical_Practice' AS TableName, COUNT(*) AS RecordCount FROM Medical_Practice
UNION ALL
SELECT 'Drugs', COUNT(*) FROM Drugs
UNION ALL
SELECT 'Prescriptions', COUNT(*) FROM Prescriptions
UNION ALL
SELECT 'Prescriptions Summary', COUNT(*) FROM [Prescription Summary];

-- Test 2: Verify Foreign Keys Work (Join Prescriptions with Medical_Practice)
SELECT TOP 5 
    p.PRESCRIPTION_CODE,
    mp.PRACTICE_NAME,
    p.ACTUAL_COST
FROM Prescriptions p
INNER JOIN Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
ORDER BY p.ACTUAL_COST DESC;

-- Test 3: Verify Foreign Keys Work (Join Prescriptions with Drugs)
SELECT TOP 5
    p.PRESCRIPTION_CODE,
    d.CHEMICAL_SUBSTANCE_BNF_DESCR AS DrugName,
    p.ACTUAL_COST
FROM Prescriptions p
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
ORDER BY p.ACTUAL_COST DESC;

-- Test 4: Full 3-Table Join (Proves Everything is Connected)
SELECT TOP 5
    p.PRESCRIPTION_CODE,
    mp.PRACTICE_NAME,
    d.CHEMICAL_SUBSTANCE_BNF_DESCR AS DrugName,
    p.ITEMS,
    p.QUANTITY,
    p.ACTUAL_COST
FROM Prescriptions p
INNER JOIN Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
ORDER BY p.ACTUAL_COST DESC;

--- QUESTION 2 : RETRIEVING DRUG RECORDS CONTAINING TABLETS OR CAPSULES
SELECT 
    BNF_CODE,
    CHEMICAL_SUBSTANCE_BNF_DESCR AS ChemicalSubstance,
    BNF_DESCRIPTION AS DrugDescription,
    BNF_CHAPTER_PLUS_CODE AS Category,
    CASE 
        WHEN BNF_DESCRIPTION LIKE '%tablet%' AND BNF_DESCRIPTION LIKE '%capsule%' 
            THEN 'Both'
        WHEN BNF_DESCRIPTION LIKE '%tablet%' THEN 'Tablet'
        WHEN BNF_DESCRIPTION LIKE '%capsule%' THEN 'Capsule'
        ELSE 'Other'
    END AS MedicationForm
FROM Drugs
WHERE BNF_DESCRIPTION LIKE '%tablet%'
   OR BNF_DESCRIPTION LIKE '%capsule%'
ORDER BY BNF_CHAPTER_PLUS_CODE, CHEMICAL_SUBSTANCE_BNF_DESCR;


---QUESTION 3: COMPUTING ROUNDED TOTAL QUANTITY FOR EACH PRESCRIPTION

SELECT 
    p.PRESCRIPTION_CODE,
    mp.PRACTICE_NAME,
    d.CHEMICAL_SUBSTANCE_BNF_DESCR AS DrugName,
    p.ITEMS AS NumberOfPacks,
    p.QUANTITY AS ItemsPerPack,
    ROUND(p.ITEMS * p.QUANTITY, 0) AS TotalQuantityRounded,
    CAST(ROUND(p.ITEMS * p.QUANTITY, 0) AS INT) AS TotalQuantity,
    p.ACTUAL_COST AS PrescriptionCost
FROM Prescriptions p
INNER JOIN Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
ORDER BY TotalQuantity DESC;

-- QUESTION 4: MOST PRESCRIBED DRUG PER MONTH 

WITH MonthlyPrescriptions AS (
    SELECT 
        ps.REPORT_MONTH,
        d.CHEMICAL_SUBSTANCE_BNF_DESCR,
        SUM(p.ITEMS) AS TotalPrescriptions,
        SUM(p.ACTUAL_COST) AS TotalCost,
        COUNT(DISTINCT p.PRACTICE_CODE) AS NumberOfPractices,
        ROW_NUMBER() OVER (
            PARTITION BY ps.REPORT_MONTH 
            ORDER BY SUM(p.ITEMS) DESC
        ) AS PrescriptionRank,
        CASE ps.REPORT_MONTH
            WHEN 'January' THEN 1
            WHEN 'February' THEN 2
            WHEN 'March' THEN 3
            WHEN 'April' THEN 4
            WHEN 'May' THEN 5
            WHEN 'June' THEN 6
            WHEN 'July' THEN 7
            WHEN 'August' THEN 8
            WHEN 'September' THEN 9
            WHEN 'October' THEN 10
            WHEN 'November' THEN 11
            WHEN 'December' THEN 12
        END AS MonthNumber
    FROM Prescriptions p
    INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
    INNER JOIN [Prescription Summary] ps ON p.PRACTICE_CODE = ps.PRACTICE_CODE
    GROUP BY ps.REPORT_MONTH, d.CHEMICAL_SUBSTANCE_BNF_DESCR
)
SELECT 
    REPORT_MONTH AS Month,
    CHEMICAL_SUBSTANCE_BNF_DESCR AS MostPrescribedDrug,
    TotalPrescriptions AS PrescriptionCount,
    TotalCost,
    NumberOfPractices
FROM MonthlyPrescriptions
WHERE PrescriptionRank = 1
ORDER BY MonthNumber;


-- QUESTION 5: STATISTICS BY BNF CHAPTER

SELECT 
    d.BNF_CHAPTER_PLUS_CODE AS Chapter,
    COUNT(p.PRESCRIPTION_CODE) AS TotalPrescriptions,
    CAST(AVG(p.ACTUAL_COST) AS DECIMAL(10,2)) AS AverageCost,
    MIN(p.ACTUAL_COST) AS MinimumCost,
    MAX(p.ACTUAL_COST) AS MaximumCost,
    CAST(SUM(p.ACTUAL_COST) AS DECIMAL(18,2)) AS TotalCost,
    CAST(STDEV(p.ACTUAL_COST) AS DECIMAL(10,2)) AS CostStandardDeviation,
    CAST(AVG(p.ITEMS) AS DECIMAL(10,2)) AS AverageItems
FROM Prescriptions p
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
GROUP BY d.BNF_CHAPTER_PLUS_CODE
ORDER BY TotalPrescriptions DESC;

-- QUESTION 6: MOST EXPENSIVE PRESCRIPTION PER PRACTICE (>£4000)
SELECT 
    mp.PRACTICE_NAME,
    mp.PRACTICE_CODE,
    mp.POSTCODE,
    p.PRESCRIPTION_CODE,
    d.CHEMICAL_SUBSTANCE_BNF_DESCR AS DrugPrescribed,
    d.BNF_DESCRIPTION AS DrugDetails,
    p.ITEMS,
    p.QUANTITY,
    p.ACTUAL_COST AS MaxPrescriptionCost
FROM Prescriptions p
INNER JOIN Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
WHERE p.ACTUAL_COST = (
    SELECT MAX(p2.ACTUAL_COST)
    FROM Prescriptions p2
    WHERE p2.PRACTICE_CODE = p.PRACTICE_CODE
)
AND p.ACTUAL_COST > 4000
ORDER BY p.ACTUAL_COST DESC;

-- QUESTION 7A :  PRACTICE SPECIALIZATION (using EXISTS)

SELECT 
    mp.PRACTICE_CODE,
    mp.PRACTICE_NAME,
    d.BNF_CHAPTER_PLUS_CODE AS SpecializedCategory,
    COUNT(p.PRESCRIPTION_CODE) AS PrescriptionsInCategory,
    CAST(SUM(p.ACTUAL_COST) AS DECIMAL(18,2)) AS CategoryCost,
    CAST(COUNT(p.PRESCRIPTION_CODE) * 100.0 / 
        (SELECT COUNT(*) FROM Prescriptions WHERE PRACTICE_CODE = mp.PRACTICE_CODE) 
        AS DECIMAL(5,2)) AS PercentageOfTotal
FROM Medical_Practice mp
INNER JOIN Prescriptions p ON mp.PRACTICE_CODE = p.PRACTICE_CODE
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
WHERE EXISTS (
    SELECT 1
    FROM Prescriptions p2
    INNER JOIN Drugs d2 ON p2.BNF_CODE = d2.BNF_CODE
    WHERE p2.PRACTICE_CODE = mp.PRACTICE_CODE
        AND d2.BNF_CHAPTER_PLUS_CODE = d.BNF_CHAPTER_PLUS_CODE
    GROUP BY d2.BNF_CHAPTER_PLUS_CODE
    HAVING COUNT(*) > 50
)
GROUP BY mp.PRACTICE_CODE, mp.PRACTICE_NAME, d.BNF_CHAPTER_PLUS_CODE
HAVING COUNT(p.PRESCRIPTION_CODE) > 50
ORDER BY PercentageOfTotal DESC;

-- QUESTION 7B: BULK PURCHASING OPPORTUNITIES (JOINs, GROUP BY, HAVING)
SELECT 
    d.CHEMICAL_SUBSTANCE_BNF_DESCR AS ChemicalSubstance,
    d.BNF_CHAPTER_PLUS_CODE AS Category,
    COUNT(DISTINCT p.PRACTICE_CODE) AS NumberOfPractices,
    SUM(p.ITEMS) AS TotalItemsOrdered,
    CAST(SUM(ROUND(p.ITEMS * p.QUANTITY, 0)) AS BIGINT) AS TotalUnitsOrdered,
    CAST(SUM(p.ACTUAL_COST) AS DECIMAL(18,2)) AS TotalCostSpent,
    CAST(AVG(p.ACTUAL_COST) AS DECIMAL(10,2)) AS AverageCostPerPrescription,
    CAST(MIN(p.ACTUAL_COST) AS DECIMAL(10,2)) AS MinCost,
    CAST(MAX(p.ACTUAL_COST) AS DECIMAL(10,2)) AS MaxCost,
    CAST(MAX(p.ACTUAL_COST) - MIN(p.ACTUAL_COST) AS DECIMAL(10,2)) AS CostVariation,
    CAST(SUM(p.ACTUAL_COST) - (COUNT(p.PRESCRIPTION_CODE) * MIN(p.ACTUAL_COST)) AS DECIMAL(18,2)) AS PotentialSavings
FROM Prescriptions p
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
INNER JOIN Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
GROUP BY d.CHEMICAL_SUBSTANCE_BNF_DESCR, d.BNF_CHAPTER_PLUS_CODE
HAVING 
    COUNT(DISTINCT p.PRACTICE_CODE) >= 5
    AND SUM(p.ITEMS) >= 100
    AND SUM(p.ACTUAL_COST) >= 500
ORDER BY PotentialSavings DESC, TotalCostSpent DESC;
GO


-- QUESTION 7C : UNUSUAL PRESCRIPTION PATTERNS (IN, System Functions)
SELECT 
    p.PRESCRIPTION_CODE,
    mp.PRACTICE_NAME,
    d.CHEMICAL_SUBSTANCE_BNF_DESCR AS Drug,
    d.BNF_DESCRIPTION,
    p.ITEMS,
    p.QUANTITY,
    p.ACTUAL_COST,
    CASE 
        WHEN p.ACTUAL_COST = 0 THEN 'Zero cost prescription'
        WHEN p.ACTUAL_COST > 5000 THEN 'Extremely high cost (>£5000)'
        WHEN p.ITEMS > 100 THEN 'Very large quantity (>100 items)'
        WHEN p.QUANTITY < 1 THEN 'Fractional quantity only'
        WHEN p.ACTUAL_COST / p.ITEMS > 1000 THEN 'Very high cost per item (>£1000)'
        ELSE 'Other unusual pattern'
    END AS UnusualPattern,
    LEN(d.BNF_DESCRIPTION) AS DescriptionLength,
    SUBSTRING(d.BNF_CHAPTER_PLUS_CODE, 1, 2) AS ChapterCode,
    YEAR(GETDATE()) AS AnalysisYear,
    DATENAME(MONTH, GETDATE()) AS AnalysisMonth
FROM Prescriptions p
INNER JOIN Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
INNER JOIN Drugs d ON p.BNF_CODE = d.BNF_CODE
WHERE p.PRESCRIPTION_CODE IN (
    SELECT PRESCRIPTION_CODE
    FROM Prescriptions
    WHERE ACTUAL_COST = 0 
       OR ACTUAL_COST > 5000
       OR ITEMS > 100
       OR QUANTITY < 1
       OR (ACTUAL_COST / ITEMS) > 1000
)
ORDER BY p.ACTUAL_COST DESC;

-- QUESTION 7D: MONTH-OVER-MONTH TRENDS (Window Functions, LAG)
WITH MonthlySummary AS (
    SELECT 
        REPORT_MONTH,
        SUM(TOTAL_ITEMS) AS MonthlyItems,
        CAST(SUM(TOTAL_COST) AS DECIMAL(18,2)) AS MonthlyCost,
        CAST(AVG(TOTAL_COST) AS DECIMAL(10,2)) AS AvgCostPerPractice,
        COUNT(DISTINCT PRACTICE_CODE) AS ActivePractices,
        CASE REPORT_MONTH
            WHEN 'January' THEN 1
            WHEN 'February' THEN 2
            WHEN 'March' THEN 3
            WHEN 'April' THEN 4
            WHEN 'May' THEN 5
            WHEN 'June' THEN 6
            WHEN 'July' THEN 7
            WHEN 'August' THEN 8
            WHEN 'September' THEN 9
            WHEN 'October' THEN 10
            WHEN 'November' THEN 11
            WHEN 'December' THEN 12
        END AS MonthNumber
    FROM [Prescription Summary]
    GROUP BY REPORT_MONTH
),
ComparativeAnalysis AS (
    SELECT 
        REPORT_MONTH,
        MonthlyItems,
        MonthlyCost,
        AvgCostPerPractice,
        ActivePractices,
        LAG(MonthlyItems, 1) OVER (ORDER BY MonthNumber) AS PreviousMonthItems,
        LAG(MonthlyCost, 1) OVER (ORDER BY MonthNumber) AS PreviousMonthCost,
        MonthNumber
    FROM MonthlySummary
)
SELECT 
    REPORT_MONTH AS Month,
    MonthlyItems AS CurrentMonthItems,
    PreviousMonthItems,
    MonthlyItems - PreviousMonthItems AS ItemsChange,
    CASE 
        WHEN PreviousMonthItems IS NOT NULL THEN
            CAST((MonthlyItems - PreviousMonthItems) * 100.0 / PreviousMonthItems AS DECIMAL(10,2))
        ELSE NULL
    END AS ItemsChangePercent,
    MonthlyCost AS CurrentMonthCost,
    PreviousMonthCost,
    MonthlyCost - PreviousMonthCost AS CostChange,
    CASE 
        WHEN PreviousMonthCost IS NOT NULL THEN
            CAST((MonthlyCost - PreviousMonthCost) * 100.0 / PreviousMonthCost AS DECIMAL(10,2))
        ELSE NULL
    END AS CostChangePercent,
    CASE 
        WHEN PreviousMonthCost IS NOT NULL AND 
             ABS((MonthlyCost - PreviousMonthCost) * 100.0 / PreviousMonthCost) > 10 
        THEN 'Significant Change (>10%)'
        WHEN PreviousMonthCost IS NOT NULL
        THEN 'Normal Variance'
        ELSE 'No Previous Data'
    END AS TrendIndicator,
    ActivePractices
FROM ComparativeAnalysis
ORDER BY MonthNumber;
