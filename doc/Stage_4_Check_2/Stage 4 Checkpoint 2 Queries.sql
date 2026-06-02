--Stored Procedure 1: Get Budget Summary Analysis
DELIMITER //
DROP PROCEDURE IF EXISTS GetBudgetSummary//
CREATE PROCEDURE GetBudgetSummary(IN user_id INT, IN month_offset INT)
BEGIN
    DECLARE target_month INT;
    DECLARE target_year INT;
    
    --target month and year
    SET target_month = MONTH(DATE_ADD(CURDATE(), INTERVAL month_offset MONTH));
    SET target_year = YEAR(DATE_ADD(CURDATE(), INTERVAL month_offset MONTH));
    
    --budget summary with spending
    SELECT 
        c.CategoryName,
        b.Max_Value AS Budget_Limit,
        COALESCE(SUM(t.Amount), 0) AS Total_Spent,
        (b.Max_Value - COALESCE(SUM(t.Amount), 0)) AS Remaining,
        CASE 
            WHEN COALESCE(SUM(t.Amount), 0) > b.Max_Value THEN 'Over Budget'
            WHEN COALESCE(SUM(t.Amount), 0) >= b.Max_Value * 0.9 THEN 'Warning'
            ELSE 'On Track'
        END AS Status
    FROM Budget b
    JOIN Category c ON b.CategoryID = c.CategoryID
    LEFT JOIN TransactionCategory tc ON c.CategoryID = tc.CategoryID
    LEFT JOIN Transactions t ON tc.TransactionID = t.TransactionID 
        AND MONTH(t.Date) = target_month 
        AND YEAR(t.Date) = target_year
    LEFT JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
        AND a.UserID = user_id
    WHERE b.UserID = user_id 
        AND b.Duration = 'Monthly'
    GROUP BY c.CategoryName, b.Max_Value, b.BudgetID
    ORDER BY Total_Spent DESC;
END //
DELIMITER ;

--Stored Procedure 2: Archive Old Transactions
DELIMITER //
CREATE PROCEDURE ArchiveOldTransactions(IN user_id INT, IN months_old INT)
BEGIN
    DECLARE archived_count INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;
    DECLARE t_id INT;
    DECLARE t_amount DECIMAL(10,2);
    DECLARE t_date DATE;
    
    --cursor to iterate through old transactions
    DECLARE transaction_cursor CURSOR FOR
        SELECT t.TransactionID, t.Amount, t.Date
        FROM Transactions t
        JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
        WHERE a.UserID = user_id
            AND t.Date < DATE_SUB(CURDATE(), INTERVAL months_old MONTH);
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    --create archive table
    CREATE TABLE IF NOT EXISTS ArchivedTransactions (
        TransactionID INT,
        Amount DECIMAL(10,2),
        Date DATE,
        ArchivedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (TransactionID)
    );
    
    OPEN transaction_cursor;
    
    read_loop: LOOP
        FETCH transaction_cursor INTO t_id, t_amount, t_date;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        --insert into archive
        INSERT INTO ArchivedTransactions (TransactionID, Amount, Date)
        VALUES (t_id, t_amount, t_date)
        ON DUPLICATE KEY UPDATE Amount = t_amount;
        
        SET archived_count = archived_count + 1;
    END LOOP;
    
    CLOSE transaction_cursor;
    
    SELECT archived_count AS Transactions_Archived;
END //
DELIMITER ;

--create Budget Alert Log Table
CREATE TABLE IF NOT EXISTS BudgetAlerts (
    AlertID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT,
    CategoryID INT,
    BudgetLimit DECIMAL(10,2),
    CurrentSpending DECIMAL(10,2),
    AlertDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserID) REFERENCES User(UserID),
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
);

--Trigger 1: Check Budget After Transaction Insert
DROP TRIGGER IF EXISTS CheckBudgetAfterTransactionCategory;

DELIMITER //
CREATE TRIGGER CheckBudgetAfterTransactionCategory
AFTER INSERT ON TransactionCategory
FOR EACH ROW
BEGIN
    DECLARE user_id INT DEFAULT NULL;
    DECLARE budget_limit DECIMAL(10,2) DEFAULT NULL;
    DECLARE current_spending DECIMAL(10,2) DEFAULT 0;
    
    --user ID from the transaction's account
    SELECT a.UserID INTO user_id
    FROM Transactions t
    JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
    WHERE t.TransactionID = NEW.TransactionID
    LIMIT 1;
    
    --proceed if we found a user
    IF user_id IS NOT NULL THEN
        --budget limit for this category
        SELECT Max_Value INTO budget_limit
        FROM Budget
        WHERE UserID = user_id 
            AND CategoryID = NEW.CategoryID
            AND Duration = 'Monthly'
        LIMIT 1;
        
        --budget exists, check spending
        IF budget_limit IS NOT NULL THEN
            --current month spending
            SELECT COALESCE(SUM(t.Amount), 0) INTO current_spending
            FROM Transactions t
            JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
            JOIN TransactionCategory tc ON t.TransactionID = tc.TransactionID
            WHERE a.UserID = user_id
                AND tc.CategoryID = NEW.CategoryID
                AND MONTH(t.Date) = MONTH(CURDATE())
                AND YEAR(t.Date) = YEAR(CURDATE());
            
            --over budget, log alert
            IF current_spending > budget_limit THEN
                INSERT INTO BudgetAlerts (UserID, CategoryID, BudgetLimit, CurrentSpending)
                VALUES (user_id, NEW.CategoryID, budget_limit, current_spending);
            END IF;
        END IF;
    END IF;
END //
DELIMITER ;

-- Trigger 2: Prevent Negative Budget
DELIMITER //
CREATE TRIGGER PreventNegativeBudget
BEFORE INSERT ON Budget
FOR EACH ROW
BEGIN
    IF NEW.Max_Value < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Budget limit cannot be negative';
    END IF;
END //
DELIMITER ;