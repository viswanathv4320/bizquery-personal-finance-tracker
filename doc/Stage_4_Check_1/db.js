const mysql = require('mysql2');
//connection to mysql
const db = mysql.createConnection({
  host: 'localhost',     
  user: 'root',          
  password: 'Pfdinc1100!!!!!!',
  database: 'BizQuery'   
});
//error handling
db.connect((err) => {
  if (err) {
    console.error('Database connection failed:', err);
  } else {
    console.log('Connected to MySQL database.');
  }
});

module.exports = db;
