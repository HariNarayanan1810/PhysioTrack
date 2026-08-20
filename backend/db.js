const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: "127.0.0.1",
  user: "root",
  password: "root",
  database: "physiotrack",
  port: 3307,
  waitForConnections: true,
  connectionLimit: 10,
});

module.exports = pool;
