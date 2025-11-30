/* UpcomingByHospital View */

CREATE OR REPLACE VIEW UpcomingByHospital AS
SELECT
    H.Name AS HospitalName,
    C.Date AS ApptDate,
    COUNT (*) AS ScheduledCount
FROM Appointment A
JOIN ClinicalActivity C ON A.CAID = C.CAID
JOIN Department D ON C.DEP_ID = D.DEP_ID
JOIN Hospital H ON D.HID = H.HID
WHERE A.Status =’Scheduled’
    AND C.Date BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE, INTERVAL
        14 DAY)
GROUP BY H.Name, C.Date;

/* DrugPricingSummary View */

CREATE OR REPLACE VIEW DrugPricingSummary AS
SELECT
    H.HID,
    H.Name AS HospitalName,
    M.MID,
    M.Name as MedicationName,
    AVG(S.UnitPrice) AS AvgUnitPrice,
    MIN(S.UnitPrice) AS MinUnitPrice,
    MAX(S.UnitPrice) AS MaxUnitPrice,
    MAX(S.StockTimestamp) AS LastStockTimestamp
FROM Stock ScheduledCount
JOIN Hospital H ON S.HID = H.HID
JOIN Medication M ON S.MID = M.MID
GROUP BY H.HID, H.Name, M.MID, M.Name;

/* StaffWorkloadThirty View */ 

CREATE OR REPLACE VIEW StaffWorkloadThirty AS
SELECT
    S.STAFF_ID, 
    S.FullName,
    COUNT (*) AS TotalAppointments,
    SUM(CASE WHEN A.Status =’Scheduled’ THEN 1 ELSE 0 END) AS
    ScheduledCount,
    SUM(CASE WHEN A.Status =’Completed’ THEN 1 ELSE 0 END) AS
    CompletedCount,
    SUM(CASE WHEN A.Status =’Cancelled’ THEN 1 ELSE 0 END) AS
    CancelledCount
FROM Staff S
JOIN ClinicalActivity C ON S.STAFF_ID = C.STAFF_ID
JOIN Appointment A ON C.CAID = A.CAID
WHERE C.Date BETWEEN DATE_SUB (CURRENT_DATE, INTERVAL 30 DAY) AND
    CURRENT_DATE
GROUP BY S.STAFF_ID, S.FullName;

/* PatientNextVisit View */

CREATE OR REPLACE VIEW PatientNextVisit AS
SELECT
    P.IID,
    P.FullName,
    C.Date AS NextApptDate,
    D.Name AS DepartmentName,
    H.Name AS HospitalName,
    H.City
FROM Patient P
JOIN ClinicalActivity C ON P.IID = C.IID
JOIN Appointment A ON C.CAID = A.CAID
JOIN Department D ON C.DEP_ID = D.DEP_ID
JOIN Hospital H ON D.HID = H.HID
WHERE A.Status =’Scheduled’
    AND C.Date > CURRENT_DATE
    AND C.Date = (
        SELECT MIN (C2.Date)
        FROM ClinicalActivity C2
        JOIN Appointment A2 ON C2.CAID = A2.CAID
        WHERE C2.IID = P.IID
        AND A2.Status =’Scheduled’
        AND C2.Date > CURRENT_DATE
    );