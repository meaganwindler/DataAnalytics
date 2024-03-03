-- Setting the database context to 'XXXXXXXXXX_Reporting'.
USE XXXXXXXXXX_Reporting;
GO

-- Before inserting fresh data, clear the sanitized.Metric table to avoid data duplication.
DELETE FROM sanitized.Metric;

-- CTE (Common Table Expression) to group and extract the 'Beginning Open' metrics based on pharmacy claim status and substatus.
-- This provides a foundational dataset to build upon in the final query.
WITH BeginningOpen AS (
    SELECT
        -- Extracting the end of the month date.
        CAST(EOM AS DATE) AS EOM,
        -- Directly selecting pharmacy claim status.
        claim_status AS Status,
        -- Determining the sub-status of the pharmacy claim based on conditions.
        CASE 
            WHEN claim_sub_status = 'Claim Filed' THEN 'Under Review'
            WHEN claim_sub_status = 'Claim Approved' THEN 'Approved'
            ELSE 'Rejected'
        END AS SubStatus,
        -- Counting the number of pharmacy claims for each group.
        COUNT(claim_skey) AS Amount
    FROM report.OPS_Exposure
    -- Excluding pharmacy claims that have been fully processed and closed.
    WHERE claim_status NOT IN ('Closed', 'Fully Processed')
    -- Grouping by the end of month date, claim status, and calculated sub-status to get aggregated counts.
    GROUP BY EOM, claim_status,
        CASE 
            WHEN claim_sub_status = 'Claim Filed' THEN 'Under Review'
            WHEN claim_sub_status = 'Claim Approved' THEN 'Approved'
            ELSE 'Rejected'
        END
)

-- Inserting data into the 'sanitized.Metrics' table, aggregating data from multiple sources.
INSERT INTO sanitized.Metrics (ID, EOM, Aggregation, Metrics, Status, SubStatus, Reason, Amount, ReportType)
SELECT 
    -- Generating a unique ID using ROW_NUMBER() for each row.
    ROW_NUMBER() OVER (ORDER BY EOM, CASE WHEN Metrics IS NULL THEN 1 ELSE 0 END, Metrics, Status, SubStatus) AS ID,
    EOM,
    'Pharmacy Claim Count' AS Aggregation,
    Metrics,
    Status,
    SubStatus,
    Reason,
    Amount,
    -- Setting a static value of 'Actual' for the ReportType column.
    'Actual' AS ReportType
FROM (
    -- Selecting the previously aggregated 'Beginning Open' metrics from the CTE.
    SELECT
        EOM,
        'Beginning Open' AS Metrics,
        Status,
        SubStatus,
        NULL AS Reason,
        Amount
    FROM BeginningOpen

    -- Adding new pharmacy claims from the 'report.OPS_Directors' table.
    UNION ALL
    SELECT
        EOM,
        'New' AS Metrics,
        NULL AS Status,
        NULL AS SubStatus,
        NULL AS Reason,
        [New_Claim_Count] AS Amount
    FROM report.OPS_Directors

    -- Adding pharmacy claims that changed status from the 'report.OPS_Directors' table.
    UNION ALL
    SELECT
        EOM,
        'Status Change' AS Metrics,
        NULL AS Status,
        NULL AS SubStatus,
        NULL AS Reason,
        [Status_Changed_Claim_Count] AS Amount
    FROM report.OPS_Directors

    -- Subtracting pharmacy claims that were fully processed.
    UNION ALL
    SELECT
        EOM,
        'Processed' AS Metrics,
        NULL AS Status,
        NULL AS SubStatus,
        'Completed Processing' AS Reason,
        -ABS([Processed_Claim_Count]) AS Amount  -- Making sure the count is represented as a negative value.
    FROM report.OPS_Directors

    -- Considering pharmacy claims that were deleted or withdrawn.
    UNION ALL
    SELECT
        EOM,
        'Deleted/Withdrawn' AS Metrics,
        NULL AS Status,
        NULL AS SubStatus,
        'Adjustments' AS Reason,
        [Deleted_Withdrawn_Claim_Count] AS Amount
    FROM report.OPS_Directors

    -- Aggregating the total value of all pharmacy claims.
    UNION ALL
    SELECT
        EOM,
        'Total Claim Value' AS Metrics,
        NULL AS Status,
        NULL AS SubStatus,
        NULL AS Reason,
        Total_Claim_Value AS Amount
    FROM report.OPS_Directors

) AS CombinedData
-- Sorting the final output by the end of month date in descending order, followed by the generated ID.
ORDER BY EOM DESC, ID;

-- Retrieve the final table content.
SELECT *
FROM sanitized.Metrics;