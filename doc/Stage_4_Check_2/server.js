//needed for the app to function
const express = require('express');
const bodyParser = require('body-parser');
const db = require('./db');
const app = express();
app.use(bodyParser.json());
app.use(express.static('public'));
const USER_ID = 256;

//GET categories request
app.get('/api/categories', (req, res) => {
  const sql = `SELECT CategoryID, CategoryName FROM Category ORDER BY CategoryID;`;
  db.query(sql, (err, results) => {
    if (err) {
      console.error('GET /api/categories error:', err);
      return res.status(500).json({ error: err });
    }
    res.json(results);
  });
});

//get budgets request
app.get('/api/budgets', (req, res) => {
  //query run for the get
    const sql = ` 
      SELECT
        b.BudgetID,
        c.CategoryName,
        b.Duration,
        b.Max_Value,
        b.ConstraintName
      FROM Budget b
      JOIN Category c ON b.CategoryID = c.CategoryID
      WHERE b.UserID = 256;
    `;
  
    db.query(sql, (err, results) => {
      if (err) {
        console.error('GET /api/budgets error:', err);
        return res.status(500).json({ error: 'Database query failed' });
      }
      res.json(results);
    });
  });
  
  
//budgets post request
app.post('/api/budgets', (req, res) => {
    const { categoryID, duration, budgetLimit, constraint } = req.body;
  
    const sql = `
      INSERT INTO Budget (UserID, CategoryID, Duration, Max_Value, ConstraintName)
      VALUES (?, ?, ?, ?, ?);
    `;
    db.query(sql, [USER_ID, categoryID, duration, budgetLimit, constraint], (err, result) => {
      if (err) {
        console.error('Error inserting budget:', err);
        return res.status(500).json({ error: err });
      }
      res.json({ message: 'Budget added successfully!', id: result.insertId });
    });
  });

 //DELETE budget request
app.delete('/api/budgets/:id', (req, res) => {
  const budgetID = req.params.id;
  const sql = `DELETE FROM Budget WHERE BudgetID = ? AND UserID = ?;`;
  db.query(sql, [budgetID, USER_ID], (err, result) => {
    if (err) {
      console.error('Error deleting budget:', err);
      return res.status(500).json({ error: err });
    }
    res.json({ message: 'Budget deleted successfully!' });
  });
});
  
//get transactions request
app.get('/api/transactions', (req, res) => {
  const { startDate, endDate, minAmount, maxAmount, paymentMethod, categoryID } = req.query;
  
  let sql = `
    SELECT
      t.TransactionID,
      t.Date,
      t.Amount,
      t.PaymentMethod,
      t.Notes,
      c.CategoryName,
      c.CategoryID
    FROM Transactions t
    JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
    LEFT JOIN TransactionCategory tc ON t.TransactionID = tc.TransactionID
    LEFT JOIN Category c ON tc.CategoryID = c.CategoryID
    WHERE a.UserID = ?
  `;
  
  const params = [USER_ID];
  //filters needed for recent transactions
  if (startDate) {
    sql += ` AND t.Date >= ?`;
    params.push(startDate);
  }
  if (endDate) {
    sql += ` AND t.Date <= ?`;
    params.push(endDate);
  }
  if (minAmount) {
    sql += ` AND t.Amount >= ?`;
    params.push(minAmount);
  }
  if (maxAmount) {
    sql += ` AND t.Amount <= ?`;
    params.push(maxAmount);
  }
  if (paymentMethod) {
    sql += ` AND t.PaymentMethod = ?`;
    params.push(paymentMethod);
  }
  if (categoryID) {
    sql += ` AND c.CategoryID = ?`;
    params.push(categoryID);
  }
  
  sql += ` ORDER BY t.Date DESC LIMIT 50;`;
  
  db.query(sql, params, (err, results) => {
    if (err) {
      console.error('GET /api/transactions error:', err);
      return res.status(500).json({ error: err });
    }
    res.json(results);
  });
});

////transactions post request for new transactions, Transaction 1: Add Transaction with Budget Check
app.post('/api/transactions', (req, res) => {
  const { date, amount, paymentMethod, notes, categoryID } = req.body;
  console.log('POST /api/transactions:', req.body);
  
  //SQL transaction
  db.beginTransaction((err) => {
    if (err) return res.status(500).json({ error: err });
    
    const getAccountSQL = `SELECT AccountNumber FROM BankAccount WHERE UserID = ? LIMIT 1;`;
    db.query(getAccountSQL, [USER_ID], (err, accounts) => {
      if (err) {
        return db.rollback(() => {
          res.status(500).json({ error: err });
        });
      }
      if (accounts.length === 0) {
        return db.rollback(() => {
          res.status(400).json({ error: 'No account found for user.' });
        });
      }

      const accountNumber = accounts[0].AccountNumber;
      const insertTransaction = `
        INSERT INTO Transactions (AccountNumber, Date, Amount, PaymentMethod, Notes)
        VALUES (?, ?, ?, ?, ?);
      `;

      db.query(insertTransaction, [accountNumber, date, amount, paymentMethod, notes], (err2, result) => {
        if (err2) {
          return db.rollback(() => {
            res.status(500).json({ error: err2 });
          });
        }

        const transactionID = result.insertId;
        
        if (categoryID) {
          const linkSQL = `INSERT INTO TransactionCategory (TransactionID, CategoryID) VALUES (?, ?);`;
          db.query(linkSQL, [transactionID, categoryID], (err3) => {
            if (err3) {
              return db.rollback(() => {
                res.status(500).json({ error: err3 });
              });
            }
            
            //check budget status
            const checkBudgetSQL = `
              SELECT b.Max_Value, 
                     (SELECT COALESCE(SUM(t2.Amount), 0)
                      FROM Transactions t2
                      JOIN BankAccount a2 ON t2.AccountNumber = a2.AccountNumber
                      JOIN TransactionCategory tc2 ON t2.TransactionID = tc2.TransactionID
                      WHERE a2.UserID = ? 
                        AND tc2.CategoryID = ?
                        AND MONTH(t2.Date) = MONTH(CURDATE())
                        AND YEAR(t2.Date) = YEAR(CURDATE())) AS current_spending
              FROM Budget b
              WHERE b.UserID = ? AND b.CategoryID = ? AND b.Duration = 'Monthly';
            `;
            
            db.query(checkBudgetSQL, [USER_ID, categoryID, USER_ID, categoryID], (err4, budgetResults) => {
              if (err4) {
                return db.rollback(() => {
                  res.status(500).json({ error: err4 });
                });
              }
              
              //commit 
              db.commit((err5) => {
                if (err5) {
                  return db.rollback(() => {
                    res.status(500).json({ error: err5 });
                  });
                }
                
                let message = 'Transaction added and linked to category!';
                let budgetWarning = null;
                
                if (budgetResults.length > 0) {
                  const { Max_Value, current_spending } = budgetResults[0];
                  if (current_spending > Max_Value) {
                    budgetWarning = `Warning: You are $${(current_spending - Max_Value).toFixed(2)} over budget!`;
                  }
                }
                
                res.json({ 
                  message, 
                  id: transactionID,
                  budgetWarning
                });
              });
            });
          });
        } else {
          db.commit((err3) => {
            if (err3) {
              return db.rollback(() => {
                res.status(500).json({ error: err3 });
              });
            }
            res.json({ message: 'Transaction added successfully!', id: transactionID });
          });
        }
      });
    });
  });
});

//transactions delete request
app.delete('/api/transactions/:id', (req, res) => {
  const transactionID = req.params.id;
  //delete from TransactionCategory
  const deleteCategory = `DELETE FROM TransactionCategory WHERE TransactionID = ?;`;
  db.query(deleteCategory, [transactionID], (err) => {
    if (err) {
      console.error('Error deleting transaction category:', err);
      return res.status(500).json({ error: err });
    }
    //delete transaction itself 
    const deleteTransaction = `
      DELETE t FROM Transactions t
      JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
      WHERE t.TransactionID = ? AND a.UserID = ?;
    `;
    db.query(deleteTransaction, [transactionID, USER_ID], (err2, result) => {
      if (err2) {
        console.error('Error deleting transaction:', err2);
        return res.status(500).json({ error: err2 });
      }
      res.json({ message: 'Transaction deleted successfully!' });
    });
  });
});

//monthly spending get request
app.get('/api/monthly-spending', (req, res) => {
    const sql = `
      SELECT
        c.CategoryName,
        SUM(t.Amount) AS Total_Spent
      FROM Transactions t
      JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
      LEFT JOIN TransactionCategory tc ON t.TransactionID = tc.TransactionID
      LEFT JOIN Category c ON tc.CategoryID = c.CategoryID
      WHERE a.UserID = ?
        AND MONTH(t.Date) = MONTH(CURDATE())
        AND YEAR(t.Date) = YEAR(CURDATE())
      GROUP BY c.CategoryName
      ORDER BY Total_Spent DESC;
    `;
    db.query(sql, [USER_ID], (err, results) => {
      if (err) {
        console.error('GET /api/monthly-spending error:', err);
        return res.status(500).json({ error: err });
      }
      res.json(results);
    });
  });

//Stored Procedure 1: Get Budget Summary 
app.get('/api/budget-summary', (req, res) => {
  const monthOffset = req.query.monthOffset || 0;
  const sql = `CALL GetBudgetSummary(?, ?);`;
  
  db.query(sql, [USER_ID, monthOffset], (err, results) => {
    if (err) {
      console.error('GET /api/budget-summary error:', err);
      return res.status(500).json({ error: err.message || err });
    }
    
    //stored procedure returns array of result sets
    //first element [0] contains actual data
    const data = Array.isArray(results) && results.length > 0 ? results[0] : [];
    res.json(data);
  });
});

//Stored Procedure 2: Archive Old Transactions 
app.post('/api/archive-transactions', (req, res) => {
  const { monthsOld } = req.body;
  const sql = `CALL ArchiveOldTransactions(?, ?);`;
  db.query(sql, [USER_ID, monthsOld || 12], (err, results) => {
    if (err) {
      console.error('POST /api/archive-transactions error:', err);
      return res.status(500).json({ error: err });
    }
    res.json(results[0][0]);
  });
});

//Trigger: Get Budget Alerts (triggered by trigger)
app.get('/api/budget-alerts', (req, res) => {
  const sql = `
    SELECT 
      ba.AlertID,
      c.CategoryName,
      ba.BudgetLimit,
      ba.CurrentSpending,
      ba.AlertDate
    FROM BudgetAlerts ba
    JOIN Category c ON ba.CategoryID = c.CategoryID
    WHERE ba.UserID = ?
    ORDER BY ba.AlertDate DESC
    LIMIT 10;
  `;
  
  db.query(sql, [USER_ID], (err, results) => {
    if (err) {
      console.error('GET /api/budget-alerts error:', err);
      return res.status(500).json({ error: err.message || err });
    }
    //queries already return the data directly, no need to extract
    res.json(results);
  });
});

//Transaction 2: Transfer Transaction Between Categories
app.post('/api/transfer-category', (req, res) => {
  const { transactionID, newCategoryID } = req.body;
  
  //SQL transaction with READ COMMITTED isolation
  db.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED', (err) => {
    if (err) return res.status(500).json({ error: err });
    
    db.beginTransaction((err2) => {
      if (err2) return res.status(500).json({ error: err2 });
      
      //verify transaction belongs to user
      const verifySQL = `
        SELECT t.TransactionID 
        FROM Transactions t
        JOIN BankAccount a ON t.AccountNumber = a.AccountNumber
        WHERE t.TransactionID = ? AND a.UserID = ?;
      `;
      
      db.query(verifySQL, [transactionID, USER_ID], (err3, results) => {
        if (err3 || results.length === 0) {
          return db.rollback(() => {
            res.status(400).json({ error: 'Transaction not found or unauthorized' });
          });
        }
        
        //delete old category link
        const deleteSQL = `DELETE FROM TransactionCategory WHERE TransactionID = ?;`;
        db.query(deleteSQL, [transactionID], (err4) => {
          if (err4) {
            return db.rollback(() => {
              res.status(500).json({ error: err4 });
            });
          }
          
          //insert new category link
          const insertSQL = `INSERT INTO TransactionCategory (TransactionID, CategoryID) VALUES (?, ?);`;
          db.query(insertSQL, [transactionID, newCategoryID], (err5) => {
            if (err5) {
              return db.rollback(() => {
                res.status(500).json({ error: err5 });
              });
            }
            
            //commit 
            db.commit((err6) => {
              if (err6) {
                return db.rollback(() => {
                  res.status(500).json({ error: err6 });
                });
              }
              res.json({ message: 'Transaction category transferred successfully!' });
            });
          });
        });
      });
    });
  });
});

app.listen(3000, () => console.log('Server running on http://localhost:3000'));