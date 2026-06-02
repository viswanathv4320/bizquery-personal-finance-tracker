--Part 1
CREATE DATABASE IF NOT EXISTS BizQuery;
USE BizQuery;

--create the tables
CREATE TABLE User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL,
    CreatedDate DATE NOT NULL
);
CREATE TABLE BankAccount (
    AccountNumber VARCHAR(20) PRIMARY KEY,
    UserID INT NOT NULL,
    RoutingNumber VARCHAR(20),
    AccountType VARCHAR(20),
    AccountOpenedDate DATE,
    FOREIGN KEY (UserID) REFERENCES User(UserID)
);
CREATE TABLE Category (
    CategoryID INT AUTO_INCREMENT PRIMARY KEY,
    CategoryName VARCHAR(50) NOT NULL
);
CREATE TABLE Transactions (
    TransactionID INT AUTO_INCREMENT PRIMARY KEY,
    AccountNumber VARCHAR(20) NOT NULL,
    Date DATE NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    PaymentMethod VARCHAR(30),
    Notes VARCHAR(255),
    FOREIGN KEY (AccountNumber) REFERENCES BankAccount(AccountNumber)
);
CREATE TABLE TransactionCategory (
    TransactionID INT NOT NULL,
    CategoryID INT NOT NULL,
    PRIMARY KEY (TransactionID, CategoryID),
    FOREIGN KEY (TransactionID) REFERENCES Transactions(TransactionID),
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
);
CREATE TABLE Budget (
    BudgetID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    CategoryID INT NOT NULL,
    Duration VARCHAR(20),
    Max_Value DECIMAL(10,2),
    ConstraintName VARCHAR(50),
    FOREIGN KEY (UserID) REFERENCES User(UserID),
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
);


--now, I need to insert 1,000 users using auto-generated data
CREATE TEMPORARY TABLE first_names (first_name VARCHAR(50));
CREATE TEMPORARY TABLE last_names (last_name VARCHAR(50));

INSERT INTO first_names (first_name) VALUES
('James'),('Mary'),('Robert'),('Patricia'),('John'),('Jennifer'),
('Michael'),('Linda'),('William'),('Elizabeth'),('David'),('Barbara'),
('Richard'),('Susan'),('Joseph'),('Jessica'),('Thomas'),('Sarah'),
('Charles'),('Karen'),('Christopher'),('Nancy'),('Daniel'),('Lisa'),
('Matthew'),('Betty'),('Anthony'),('Margaret'),('Mark'),('Sandra');

INSERT INTO last_names (last_name) VALUES
('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),
('Miller'),('Davis'),('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),
('Gonzalez'),('Wilson'),('Anderson'),('Thomas'),('Taylor'),('Moore'),
('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),('White'),
('Harris'),('Sanchez'),('Clark'),('Ramirez'),('Lewis'),('Robinson');

--insert the unique users
INSERT INTO User (Username, CreatedDate)
SELECT 
    CONCAT(
        LOWER(f.first_name), '.', LOWER(f.last_name), LPAD(numbers.n, 3, '0')
    ) AS Username,
    CURDATE() - INTERVAL FLOOR(RAND()*3650) DAY AS CreatedDate
FROM (
    SELECT a.first_name, b.last_name
    FROM first_names a
    CROSS JOIN last_names b
) AS f
JOIN (
    SELECT t1.n + t2.n*10 + t3.n*100 AS n
    FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1
    CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2
    CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3
) AS numbers
ORDER BY RAND()
LIMIT 1000;

DROP TEMPORARY TABLE tmp_first_names;
DROP TEMPORARY TABLE tmp_last_names;

--now, insert 1,000 bank accounts using auto-generated data
INSERT INTO BankAccount (AccountNumber, UserID, RoutingNumber, AccountType, AccountOpenedDate)
SELECT 
    CONCAT('AC', LPAD(FLOOR(10000000 + RAND()*89999999), 8, '0')) AS AccountNumber,
    u.UserID,
    CONCAT(LPAD(FLOOR(100000000 + RAND()*899999999), 9, '0')) AS RoutingNumber,
    ELT(FLOOR(1 + RAND()*3), 'Checking', 'Savings', 'Investment') AS AccountType,
    CURDATE() - INTERVAL FLOOR(RAND()*3650) DAY AS AccountOpenedDate
FROM User u
WHERE u.UserID BETWEEN 256 AND 1255;

--now, insert 1,000 auto genrerated transactions for a single user
INSERT INTO Transactions (AccountNumber, TransactionDate, Amount, PaymentMethod, Notes)
SELECT 
    'AC87349050' AS AccountNumber,
    DATE_ADD('2025-06-18', INTERVAL FLOOR(RAND() * DATEDIFF(CURDATE(), '2025-06-18')) DAY) AS TransactionDate,
    ROUND((RAND()*2000 - 1000), 2) AS Amount, --random between -1000 and 1000
    ELT(FLOOR(1 + RAND()*5), 'Cash', 'Credit Card', 'Debit Card', 'Check', 'Online') AS PaymentMethod,
    ELT(FLOOR(1 + RAND()*5), 'Groceries', 'Rent', 'Utilities', 'Entertainment', 'Misc') AS Notes
FROM (
    SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
) temp1
CROSS JOIN (
    SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
) tem2
CROSS JOIN (
    SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
) temp3
LIMIT 1000;

--set transaction notes to NULL
UPDATE Transactions
SET Notes = NULL
WHERE AccountNumber = 'AC87349050';

--insert categories
INSERT INTO Category (CategoryName) VALUES
('Groceries'),
('Rent'),
('Utilities'),
('Entertainment'),
('Dining'),
('Transportation'),
('Healthcare'),
('Education'),
('Shopping'),
('Miscellaneous');

--insert into transaction category
INSERT INTO TransactionCategory (TransactionID, CategoryID)
SELECT 
    t.TransactionID,
    FLOOR(1 + RAND()*10) AS CategoryID --1-10 `CategoryID`
FROM Transactions t
WHERE t.AccountNumber = 'AC87349050';

-- Insert a few budgets for a user
INSERT INTO Budget (UserID, CategoryID, Duration, MaxValue, ConstraintName)
VALUES
(256, 1, 'Monthly', 500.00, 'Groceries limit'),       
(256, 2, 'Monthly', 1200.00, 'Rent payment'),         
(256, 3, 'Monthly', 300.00, 'Utilities cap'),         
(256, 5, 'Monthly', 250.00, 'Dining out limit'),      
(256, 4, 'Monthly', 200.00, 'Entertainment cap');     

--these counts show 1,000 rows in 3 tables
SELECT COUNT(*) FROM User;
SELECT COUNT(*) FROM bankaccount;
SELECT COUNT(*) FROM transactions;

--Query 1: Monthly Spending by Category for One User
SELECT
    c.CategoryName,
    SUM(t.Amount) AS TotalSpent
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
  AND t.Date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
GROUP BY c.CategoryName
ORDER BY TotalSpent DESC;

--Query 2: User Exceeding Budget Limits
SELECT
    u.Username,
    c.CategoryName,
    bu.Duration,
    SUM(t.Amount) AS TotalSpent,
    bu.Max_Value AS BudgetLimit
FROM User u
JOIN BankAccount ba
    ON u.UserID = ba.UserID
JOIN Transactions t
    ON ba.AccountNumber = t.AccountNumber
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN Budget bu
    ON bu.UserID = u.UserID AND bu.CategoryID = c.CategoryID
WHERE u.UserID = 256 AND t.Amount > 0  
GROUP BY u.Username, c.CategoryName, bu.Duration, bu.Max_Value
HAVING SUM(t.Amount) > bu.Max_Value;

--Query 3: Average Transaction Amount per Payment Method
SELECT t.PaymentMethod, AVG(t.Amount) AS AvgTransaction,
    (SELECT AVG(t2.Amount)
     FROM Transactions t2
     JOIN BankAccount b2 ON t2.AccountNumber = b2.AccountNumber
     WHERE b2.UserID = 256) AS OverallAvg
FROM Transactions t
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
GROUP BY t.PaymentMethod
ORDER BY AvgTransaction DESC;

--Query 4: Last Few Transactions per Category
SELECT
    t.TransactionID,
    t.Date AS TransactionDate,
    t.Amount,
    t.PaymentMethod,
    c.CategoryName
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
LEFT JOIN Transactions t2
    JOIN TransactionCategory tc2
        ON t2.TransactionID = tc2.TransactionID
    ON tc.CategoryID = tc2.CategoryID
    AND b.UserID = 256 AND t.Date < t2.Date AND t.AccountNumber = t2.AccountNumber
WHERE b.UserID = 256
GROUP BY t.TransactionID, c.CategoryName, t.Date, t.Amount, t.PaymentMethod
HAVING COUNT(t2.TransactionID) < 5
ORDER BY c.CategoryName, t.Date DESC
LIMIT 15;

--Part 2

--Query 1 Analysis
EXPLAIN ANALYZE
SELECT
    c.CategoryName,
    SUM(t.Amount) AS TotalSpent
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
  AND t.Date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
GROUP BY c.CategoryName
ORDER BY TotalSpent DESC;

--Index #1
CREATE INDEX idx_transactions_date_acc
ON Transactions (Date, AccountNumber);


EXPLAIN ANALYZE
SELECT
    c.CategoryName,
    SUM(t.Amount) AS TotalSpent
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
  AND t.Date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
GROUP BY c.CategoryName
ORDER BY TotalSpent DESC;

--Index #2
CREATE INDEX i_bankaccount_user
ON BankAccount (UserID);


EXPLAIN ANALYZE
SELECT
    c.CategoryName,
    SUM(t.Amount) AS TotalSpent
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
  AND t.Date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
GROUP BY c.CategoryName
ORDER BY TotalSpent DESC;

--Index #3
CREATE INDEX i_tc_categoryid ON TransactionCategory(CategoryID);


EXPLAIN ANALYZE
SELECT
    c.CategoryName,
    SUM(t.Amount) AS TotalSpent
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
  AND t.Date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
GROUP BY c.CategoryName
ORDER BY TotalSpent DESC;

--Query #2 Analysis
EXPLAIN ANALYZE
SELECT
    u.Username,
    c.CategoryName,
    bu.Duration,
    SUM(t.Amount) AS TotalSpent,
    bu.Max_Value AS BudgetLimit
FROM User u
JOIN BankAccount ba
    ON u.UserID = ba.UserID
JOIN Transactions t
    ON ba.AccountNumber = t.AccountNumber
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN Budget bu
    ON bu.UserID = u.UserID AND bu.CategoryID = c.CategoryID
WHERE u.UserID = 256 AND t.Amount > 0  
GROUP BY u.Username, c.CategoryName, bu.Duration, bu.Max_Value
HAVING SUM(t.Amount) > bu.Max_Value;

--Index #1
CREATE INDEX i_ba_userid ON BankAccount(UserID);

EXPLAIN ANALYZE
SELECT
    u.Username,
    c.CategoryName,
    bu.Duration,
    SUM(t.Amount) AS TotalSpent,
    bu.Max_Value AS BudgetLimit
FROM User u
JOIN BankAccount ba
    ON u.UserID = ba.UserID
JOIN Transactions t
    ON ba.AccountNumber = t.AccountNumber
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN Budget bu
    ON bu.UserID = u.UserID AND bu.CategoryID = c.CategoryID
WHERE u.UserID = 256 AND t.Amount > 0  
GROUP BY u.Username, c.CategoryName, bu.Duration, bu.Max_Value
HAVING SUM(t.Amount) > bu.Max_Value;

--Index #2
CREATE INDEX i_t_an ON Transactions(AccountNumber);

EXPLAIN ANALYZE
SELECT
    u.Username,
    c.CategoryName,
    bu.Duration,
    SUM(t.Amount) AS TotalSpent,
    bu.Max_Value AS BudgetLimit
FROM User u
JOIN BankAccount ba
    ON u.UserID = ba.UserID
JOIN Transactions t
    ON ba.AccountNumber = t.AccountNumber
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN Budget bu
    ON bu.UserID = u.UserID AND bu.CategoryID = c.CategoryID
WHERE u.UserID = 256 AND t.Amount > 0  
GROUP BY u.Username, c.CategoryName, bu.Duration, bu.Max_Value
HAVING SUM(t.Amount) > bu.Max_Value;

--Index #3
CREATE INDEX i_amount ON Transactions(Amount);

EXPLAIN ANALYZE
SELECT
    u.Username,
    c.CategoryName,
    bu.Duration,
    SUM(t.Amount) AS TotalSpent,
    bu.Max_Value AS BudgetLimit
FROM User u
JOIN BankAccount ba
    ON u.UserID = ba.UserID
JOIN Transactions t
    ON ba.AccountNumber = t.AccountNumber
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN Budget bu
    ON bu.UserID = u.UserID AND bu.CategoryID = c.CategoryID
WHERE u.UserID = 256 AND t.Amount > 0  
GROUP BY u.Username, c.CategoryName, bu.Duration, bu.Max_Value
HAVING SUM(t.Amount) > bu.Max_Value;

--Query #3 Analysis
EXPLAIN ANALYZE
SELECT t.PaymentMethod, AVG(t.Amount) AS AvgTransaction,
    (SELECT AVG(t2.Amount)
     FROM Transactions t2
     JOIN BankAccount b2 ON t2.AccountNumber = b2.AccountNumber
     WHERE b2.UserID = 256) AS OverallAvg
FROM Transactions t
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
GROUP BY t.PaymentMethod
ORDER BY AvgTransaction DESC;

--Index #1
CREATE INDEX i_tran_ac ON Transactions(AccountNumber);

EXPLAIN ANALYZE
SELECT t.PaymentMethod, AVG(t.Amount) AS AvgTransaction,
    (SELECT AVG(t2.Amount)
     FROM Transactions t2
     JOIN BankAccount b2 ON t2.AccountNumber = b2.AccountNumber
     WHERE b2.UserID = 256) AS OverallAvg
FROM Transactions t
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
GROUP BY t.PaymentMethod
ORDER BY AvgTransaction DESC;

--Index #2
CREATE INDEX i_tp ON Transactions(PaymentMethod);

EXPLAIN ANALYZE
SELECT t.PaymentMethod, AVG(t.Amount) AS AvgTransaction,
    (SELECT AVG(t2.Amount)
     FROM Transactions t2
     JOIN BankAccount b2 ON t2.AccountNumber = b2.AccountNumber
     WHERE b2.UserID = 256) AS OverallAvg
FROM Transactions t
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
GROUP BY t.PaymentMethod
ORDER BY AvgTransaction DESC;

--Index #3
CREATE INDEX i_taa ON Transactions(AccountNumber, Amount);

EXPLAIN ANALYZE
SELECT t.PaymentMethod, AVG(t.Amount) AS AvgTransaction,
    (SELECT AVG(t2.Amount)
     FROM Transactions t2
     JOIN BankAccount b2 ON t2.AccountNumber = b2.AccountNumber
     WHERE b2.UserID = 256) AS OverallAvg
FROM Transactions t
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
WHERE b.UserID = 256
GROUP BY t.PaymentMethod
ORDER BY AvgTransaction DESC;

--Query #4 Analysis
EXPLAIN ANALYZE
SELECT
    t.TransactionID,
    t.Date AS TransactionDate,
    t.Amount,
    t.PaymentMethod,
    c.CategoryName
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
LEFT JOIN Transactions t2
    JOIN TransactionCategory tc2
        ON t2.TransactionID = tc2.TransactionID
    ON tc.CategoryID = tc2.CategoryID
    AND b.UserID = 256 AND t.Date < t2.Date AND t.AccountNumber = t2.AccountNumber
WHERE b.UserID = 256
GROUP BY t.TransactionID, c.CategoryName, t.Date, t.Amount, t.PaymentMethod
HAVING COUNT(t2.TransactionID) < 5
ORDER BY c.CategoryName, t.Date DESC
LIMIT 15;

--Index #1
CREATE INDEX i_tad ON Transactions(AccountNumber, Date);

EXPLAIN ANALYZE
SELECT
    t.TransactionID,
    t.Date AS TransactionDate,
    t.Amount,
    t.PaymentMethod,
    c.CategoryName
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
LEFT JOIN Transactions t2
    JOIN TransactionCategory tc2
        ON t2.TransactionID = tc2.TransactionID
    ON tc.CategoryID = tc2.CategoryID
    AND b.UserID = 256 AND t.Date < t2.Date AND t.AccountNumber = t2.AccountNumber
WHERE b.UserID = 256
GROUP BY t.TransactionID, c.CategoryName, t.Date, t.Amount, t.PaymentMethod
HAVING COUNT(t2.TransactionID) < 5
ORDER BY c.CategoryName, t.Date DESC
LIMIT 15;

--Index #2
CREATE INDEX i_tctid ON TransactionCategory(TransactionID);

EXPLAIN ANALYZE
SELECT
    t.TransactionID,
    t.Date AS TransactionDate,
    t.Amount,
    t.PaymentMethod,
    c.CategoryName
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
LEFT JOIN Transactions t2
    JOIN TransactionCategory tc2
        ON t2.TransactionID = tc2.TransactionID
    ON tc.CategoryID = tc2.CategoryID
    AND b.UserID = 256 AND t.Date < t2.Date AND t.AccountNumber = t2.AccountNumber
WHERE b.UserID = 256
GROUP BY t.TransactionID, c.CategoryName, t.Date, t.Amount, t.PaymentMethod
HAVING COUNT(t2.TransactionID) < 5
ORDER BY c.CategoryName, t.Date DESC
LIMIT 15;

--Index #3
CREATE INDEX i_tan ON Transactions(AccountNumber);

EXPLAIN ANALYZE
SELECT
    t.TransactionID,
    t.Date AS TransactionDate,
    t.Amount,
    t.PaymentMethod,
    c.CategoryName
FROM Transactions t
JOIN TransactionCategory tc
    ON t.TransactionID = tc.TransactionID
JOIN Category c
    ON tc.CategoryID = c.CategoryID
JOIN BankAccount b
    ON t.AccountNumber = b.AccountNumber
LEFT JOIN Transactions t2
    JOIN TransactionCategory tc2
        ON t2.TransactionID = tc2.TransactionID
    ON tc.CategoryID = tc2.CategoryID
    AND b.UserID = 256 AND t.Date < t2.Date AND t.AccountNumber = t2.AccountNumber
WHERE b.UserID = 256
GROUP BY t.TransactionID, c.CategoryName, t.Date, t.Amount, t.PaymentMethod
HAVING COUNT(t2.TransactionID) < 5
ORDER BY c.CategoryName, t.Date DESC
LIMIT 15;