//load the categories from the server using query info
async function loadCategories() {
  const res = await fetch('/api/categories');
  const data = await res.json();
  const tbody = document.querySelector('#categoryTable tbody');
  tbody.innerHTML = data.map(c => `
    <tr>
      <td>${c.CategoryID}</td>
      <td>${c.CategoryName}</td>
    </tr>
  `).join('');
}
//load month spending from server
async function loadMonthlySpending() {
const res = await fetch('/api/monthly-spending');
const data = await res.json();
const tbody = document.querySelector('#monthlySpendingTable tbody');
//data shows no spending for the month
if (data.length === 0) {
  tbody.innerHTML = '<tr><td colspan="2" class="text-center">No spending data for this month</td></tr>';
  return;
}
//takes the summ of the spending for the month
const total = data.reduce((sum, item) => sum + parseFloat(item.Total_Spent || 0), 0);
//uses query info and fixes it to the table
tbody.innerHTML = data.map(s => `
  <tr>
    <td>${s.CategoryName || 'Uncategorized'}</td>
    <td>$${parseFloat(s.Total_Spent).toFixed(2)}</td>
  </tr>
`).join('') + `
  <tr class="table-info fw-bold">
    <td>Total</td>
    <td>$${total.toFixed(2)}</td>
  </tr>
`;
}
//loads budgets using server and query info
async function loadBudgets() {
  const res = await fetch('/api/budgets');
  const data = await res.json();
  const tbody = document.querySelector('#budgetTable tbody');
  tbody.innerHTML = data.map(b => `
  <tr>
      <td>${b.CategoryName}</td>
      <td>${b.Duration}</td>
      <td>$${b.Max_Value}</td>
      <td>${b.ConstraintName || ''}</td>
      <td><button class="btn btn-danger btn-sm" onclick="deleteBudget(${b.BudgetID})">Delete</button></td>
  </tr>
  `).join('');
}

//loads transactions using query information
async function loadTransactions(filters = {}) {
const queryParams = new URLSearchParams();
//set the different filters
if (filters.date) {
  queryParams.append('startDate', filters.date);
  queryParams.append('endDate', filters.date);
}
if (filters.minAmount) queryParams.append('minAmount', filters.minAmount);
if (filters.maxAmount) queryParams.append('maxAmount', filters.maxAmount);
if (filters.paymentMethod) queryParams.append('paymentMethod', filters.paymentMethod);
if (filters.categoryID) queryParams.append('categoryID', filters.categoryID);
//sets the query info
const url = `/api/transactions${queryParams.toString() ? '?' + queryParams.toString() : ''}`;
const res = await fetch(url);
const data = await res.json();
const tbody = document.querySelector('#transactionTable tbody');
//none found for the set filter
if (data.length === 0) {
  tbody.innerHTML = '<tr><td colspan="6" class="text-center">No transactions found</td></tr>';
  return;
}
//get query info and place in correct spot in table
tbody.innerHTML = data.map(t =>
  `<tr>
    <td>${t.Date}</td>
    <td>$${t.Amount}</td>
    <td>${t.PaymentMethod}</td>
    <td>${t.CategoryName || ''}</td>
    <td>${t.Notes || ''}</td>
    <td><button class="btn btn-danger btn-sm" onclick="deleteTransaction(${t.TransactionID})">Delete</button></td>
  </tr>`
).join('');
}
//deleting budget button
async function deleteBudget(budgetID) {
if (!confirm('Are you sure you want to delete this budget?')) return;
//delete it
await fetch(`/api/budgets/${budgetID}`, {
  method: 'DELETE'
});
loadBudgets();
}
//delet transactions button
async function deleteTransaction(transactionID) {
if (!confirm('Are you sure you want to delete this transaction?')) return;
//delete it
await fetch(`/api/transactions/${transactionID}`, {
  method: 'DELETE'
});
loadTransactions();
loadMonthlySpending();
}
//clear filters button, reset
function clearFilters() {
document.getElementById('filterForm').reset();
loadTransactions();
}
//sends info back to the api for transactions and awaits furter information by user
document.getElementById('transactionForm').addEventListener('submit', async (e) => {
e.preventDefault();
const formData = Object.fromEntries(new FormData(e.target).entries());
await fetch('/api/transactions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(formData)
});
e.target.reset();
loadTransactions();
loadMonthlySpending();
});
//sends info back to the api for budgets and awaits further info from user
document.getElementById('budgetForm').addEventListener('submit', async (e) => {
e.preventDefault();
const formData = Object.fromEntries(new FormData(e.target).entries());
await fetch('/api/budgets', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(formData)
});
e.target.reset();
loadBudgets();
});
//handles info for filters and waits for info from user
document.getElementById('filterForm').addEventListener('submit', async (e) => {
e.preventDefault();
const formData = Object.fromEntries(new FormData(e.target).entries());

//makes sure empty values arent an issue
const filters = {};
for (const [key, value] of Object.entries(formData)) {
  if (value) filters[key] = value;
}

loadTransactions(filters);
});
//make sure to load categories, monthly spending, budgets, and transactions
loadCategories();
loadMonthlySpending();
loadBudgets();
loadTransactions();