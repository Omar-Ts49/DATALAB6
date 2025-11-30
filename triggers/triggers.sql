/* Trigger 1 */

CREATE TRIGGER reject_double_booking_insert
BEFORE INSERT ON Appointment
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
		FROM ClinicalActivity CA
		JOIN Appointment A 
		where A.CAID = CA.CAID
		and CA.staff_ID = (select staff_id from clinicalactivity where CAID=new.CAID)
		and CA.date = (select date from clinicalactivity where CAID=new.CAID)
		and CA.time = (select time from clinicalactivity where CAID=new.CAID)
    ) THEN
        SIGNAL SQLSTATE '45000' -- after searching this is the number commonely used for personnal errors or custom ones
        SET MESSAGE_TEXT = 'Error: Staff member already has an appointment at this date and time.';
    END IF;
END

CREATE TRIGGER reject_double_booking_update
BEFORE UPDATE ON Appointment
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ClinicalActivity CA
        WHERE CA.STAFF_ID = (SELECT STAFF_ID FROM ClinicalActivity WHERE CAID = NEW.CAID)
          AND CA.Date = (SELECT Date FROM ClinicalActivity WHERE CAID = NEW.CAID)
          AND CA.Time = (SELECT Time FROM ClinicalActivity WHERE CAID = NEW.CAID)
          AND CA.CAID <> OLD.CAID      -- avoid matching the same appointment
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Staff member already has an appointment at this date and time.';
    END IF;
END



/* Trigger 2 */

CREATE TRIGGER AfterInsertIncludes
AFTER INSERT ON Includes
FOR EACH ROW
BEGIN
    DECLARE total_amount DECIMAL(10,2);
    DECLARE activity_caid INT;
    DECLARE hospital_hid INT;
    DECLARE missing_price INT DEFAULT 0;
    
    SELECT p.CAID, d.HID INTO activity_caid, hospital_hid
    FROM Prescription p
    JOIN ClinicalActivity ca ON p.CAID = ca.CAID
    JOIN Department d ON ca.DEP_ID = d.DEP_ID
    WHERE p.PRID = NEW.PRID;
    
    SELECT COUNT(*) INTO missing_price
    FROM Includes i
    JOIN Prescription p ON i.PRID = p.PRID
    JOIN ClinicalActivity ca ON p.CAID = ca.CAID
    JOIN Department d ON ca.DEP_ID = d.DEP_ID
    LEFT JOIN Stock s ON s.MID = i.MID AND s.HID = d.HID
    WHERE p.PRID = NEW.PRID AND s.UnitPrice IS NULL;
    
    IF missing_price > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot update expense total: missing unit price for one or more medications';
    ELSE

        SELECT SUM(i.Quantity * s.UnitPrice) INTO total_amount
        FROM Includes i
        JOIN Prescription p ON i.PRID = p.PRID
        JOIN ClinicalActivity ca ON p.CAID = ca.CAID
        JOIN Department d ON ca.DEP_ID = d.DEP_ID
        JOIN Stock s ON s.MID = i.MID AND s.HID = d.HID
        WHERE p.PRID = NEW.PRID;
        
        UPDATE Expense 
        SET Total = COALESCE(total_amount, 0)
        WHERE CAID = activity_caid;
    END IF;
END


CREATE TRIGGER AfterUpdateIncludes
AFTER UPDATE ON Includes
FOR EACH ROW
BEGIN
    DECLARE total_amount DECIMAL(10,2);
    DECLARE activity_caid INT;
    DECLARE hospital_hid INT;
    DECLARE missing_price INT DEFAULT 0;

    SELECT p.CAID, d.HID INTO activity_caid, hospital_hid
    FROM Prescription p
    JOIN ClinicalActivity ca ON p.CAID = ca.CAID
    JOIN Department d ON ca.DEP_ID = d.DEP_ID
    WHERE p.PRID = NEW.PRID;
    
    SELECT COUNT(*) INTO missing_price
    FROM Includes i
    JOIN Prescription p ON i.PRID = p.PRID
    JOIN ClinicalActivity ca ON p.CAID = ca.CAID
    JOIN Department d ON ca.DEP_ID = d.DEP_ID
    LEFT JOIN Stock s ON s.MID = i.MID AND s.HID = d.HID
    WHERE p.PRID = NEW.PRID AND s.UnitPrice IS NULL;
    
    IF missing_price > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot update expense total: missing unit price for one or more medications';
    ELSE
        SELECT SUM(i.Quantity * s.UnitPrice) INTO total_amount
        FROM Includes i
        JOIN Prescription p ON i.PRID = p.PRID
        JOIN ClinicalActivity ca ON p.CAID = ca.CAID
        JOIN Department d ON ca.DEP_ID = d.DEP_ID
        JOIN Stock s ON s.MID = i.MID AND s.HID = d.HID
        WHERE p.PRID = NEW.PRID;
        
        UPDATE Expense 
        SET Total = COALESCE(total_amount, 0)
        WHERE CAID = activity_caid;
    END IF;
END


CREATE TRIGGER AfterDeleteIncludes
AFTER DELETE ON Includes
FOR EACH ROW
BEGIN
    DECLARE total_amount DECIMAL(10,2);
    DECLARE activity_caid INT;
    DECLARE hospital_hid INT;
    DECLARE missing_price INT DEFAULT 0;

    SELECT p.CAID, d.HID INTO activity_caid, hospital_hid
    FROM Prescription p
    JOIN ClinicalActivity ca ON p.CAID = ca.CAID
    JOIN Department d ON ca.DEP_ID = d.DEP_ID
    WHERE p.PRID = OLD.PRID;
    
    SELECT COUNT(*) INTO missing_price
    FROM Includes i
    JOIN Prescription p ON i.PRID = p.PRID
    JOIN ClinicalActivity ca ON p.CAID = ca.CAID
    JOIN Department d ON ca.DEP_ID = d.DEP_ID
    LEFT JOIN Stock s ON s.MID = i.MID AND s.HID = d.HID
    WHERE p.PRID = OLD.PRID AND s.UnitPrice IS NULL;
    
    IF missing_price > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot update expense total: missing unit price for one or more medications';
    ELSE
        SELECT SUM(i.Quantity * s.UnitPrice) INTO total_amount
        FROM Includes i
        JOIN Prescription p ON i.PRID = p.PRID
        JOIN ClinicalActivity ca ON p.CAID = ca.CAID
        JOIN Department d ON ca.DEP_ID = d.DEP_ID
        JOIN Stock s ON s.MID = i.MID AND s.HID = d.HID
        WHERE p.PRID = OLD.PRID;
        UPDATE Expense 
        SET Total = COALESCE(total_amount, 0)
        WHERE CAID = activity_caid;
    END IF;
END

/* Trigger 3 */

CREATE TRIGGER check_stock_insert
BEFORE INSERT ON Stock
FOR EACH ROW
BEGIN
    IF NEW.Qty < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Qty cannot be negative.';
    END IF;

    IF NEW.UnitPrice <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: UnitPrice must be greater than zero.';
    END IF;

    IF NEW.ReorderLevel < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: ReorderLevel cannot be negative.';
    END IF;
END

CREATE TRIGGER check_stock_update
BEFORE UPDATE ON Stock
FOR EACH ROW
BEGIN
    IF NEW.Qty < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Qty cannot be negative.';
    END IF;

    IF NEW.UnitPrice <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: UnitPrice must be greater than zero.';
    END IF;

    IF NEW.ReorderLevel < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: ReorderLevel cannot be negative.';
    END IF;

    -- Prevent decreasing Qty below zero
    IF NEW.Qty < OLD.Qty AND NEW.Qty < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Qty decrease would drop below zero.';
    END IF;
END


/* Trigger 4 */

CREATE TRIGGER BeforeDeletePatient
BEFORE DELETE ON Patient
FOR EACH ROW
BEGIN
    DECLARE activity_count INT;
    
    SELECT COUNT(*) INTO activity_count
    FROM ClinicalActivity
    WHERE IID = OLD.IID;
    
    IF activity_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete patient: Patient has existing clinical activities. Please reassign or delete dependent activities first.';
    END IF;
END