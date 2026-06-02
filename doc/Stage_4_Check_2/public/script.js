//start with pie chart as empty
let categoryPieChart = null;

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

//creates the pie chart using query and transaction info
async function loadCategoryPieChart() {
  const res = await fetch('/api/monthly-spending');
  const data = await res.json();
  //gets the created Pie Chart from above
  const ctx = document.getElementById('categoryPieChart').getContext('2d');
  //shouldnt ever run this
  if (categoryPieChart) {
    categoryPieChart.destroy();
  }
  //set the color as the rainbow
  const colors = [
    'rgb(255, 99, 132)',
    'rgb(54, 162, 235)',
    'rgb(255, 205, 86)',
    'rgb(75, 192, 192)',
    'rgb(153, 102, 255)',
    'rgb(255, 159, 64)',
    'rgb(201, 203, 207)',
    'rgb(255, 99, 71)',
    'rgb(144, 238, 144)',
    'rgb(221, 160, 221)'
  ];
  //this creates our pie chart using the datamap given to it (transaction information)
  categoryPieChart = new Chart(ctx, {
    type: 'pie',
    data: {
      labels: data.map(d => d.CategoryName || 'Uncategorized'),
      datasets: [{
        data: data.map(d => parseFloat(d.Total_Spent)),
        backgroundColor: colors.slice(0, data.length)
      }]
    },
    options: {
      responsive: true,
      plugins: {
        legend: {
          position: 'bottom'
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              const label = context.label || '';
              const value = context.parsed || 0;
              return label + ': $' + value.toFixed(2);
            }
          }
        }
      }
    }
  });
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
  loadCategoryPieChart();
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
  loadCategoryPieChart();
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

//function to update and run the budgets summary using the api
async function loadBudgetSummary() {
  try { //try getting the information, this did not work earlier
    const res = await fetch('/api/budget-summary');
    if (!res.ok) throw new Error('Failed to load budget summary');

    const data = await res.json();
    const tbody = document.querySelector('#budgetSummaryTable tbody');
    //no data
    if (!Array.isArray(data) || data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center">No budget data available</td></tr>';
      return;
    }
    //this gives us the on track, warning, or over budget signal if we spent too much
    tbody.innerHTML = data.map(row => {
      const statusClass = row.Status === 'Over Budget' ? 'text-danger fw-bold' : 
                         row.Status === 'Warning' ? 'text-warning' : 'text-success';
      return `
        <tr>
          <td>${row.CategoryName}</td>
          <td>$${parseFloat(row.Budget_Limit).toFixed(2)}</td>
          <td>$${parseFloat(row.Total_Spent).toFixed(2)}</td>
          <td>$${parseFloat(row.Remaining).toFixed(2)}</td>
          <td class="${statusClass}">${row.Status}</td>
        </tr>
      `;
    }).join('');
  } catch (error) {
    console.error('Error loading budget summary:', error);
    document.querySelector('#budgetSummaryTable tbody').innerHTML = 
      '<tr><td colspan="5" class="text-center text-danger">Error loading data</td></tr>';
  }
}

//function to run the budget alerts using the api
async function loadBudgetAlerts() {
  try { //try running the budget alerts 
    const res = await fetch('/api/budget-alerts');
    if (!res.ok) throw new Error('Failed to load budget alerts');
    const data = await res.json();
    const tbody = document.querySelector('#budgetAlertsTable tbody');
    //no budget alerts made
    if (data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="4" class="text-center">No budget alerts</td></tr>';
      return;
    }
    //gives us the alert and the name of the budget
    tbody.innerHTML = data.map(alert => `
      <tr>
        <td>${alert.CategoryName}</td>
        <td>$${parseFloat(alert.BudgetLimit).toFixed(2)}</td>
        <td class="text-danger">$${parseFloat(alert.CurrentSpending).toFixed(2)}</td>
        <td>${new Date(alert.AlertDate).toLocaleString()}</td>
      </tr>
    `).join('');
  } catch (error) {
    console.error('Error loading budget alerts:', error);
    document.querySelector('#budgetAlertsTable tbody').innerHTML = 
      '<tr><td colspan="4" class="text-center text-danger">Error loading data</td></tr>';
  }
}

//grabs the information and updates user for the Archiving of transactions
document.getElementById('archiveForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const formData = Object.fromEntries(new FormData(e.target).entries());
  const monthsOld = formData.monthsOld || 12;
  //fecthes the archives from api
  const res = await fetch('/api/archive-transactions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ monthsOld })
  });
  //it worked
  const result = await res.json();
  document.getElementById('archiveResult').innerHTML = 
    `<div class="alert alert-success">${result.Transactions_Archived} transactions archived successfully!</div>`;
  setTimeout(() => {
    document.getElementById('archiveResult').innerHTML = '';
  }, 3000);
});

//this is the transfer category operation controlled bu the transaction
document.getElementById('transferForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const formData = Object.fromEntries(new FormData(e.target).entries());
  //gmake the request
  const res = await fetch('/api/transfer-category', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(formData)
  });
  const result = await res.json();
  //it worked
  if (res.ok) {
    document.getElementById('transferResult').innerHTML = 
      `<div class="alert alert-success">${result.message}</div>`;
    loadTransactions();
  } else { //did not work
    document.getElementById('transferResult').innerHTML = 
      `<div class="alert alert-danger">Error: ${result.error}</div>`;
  }
  setTimeout(() => {
    document.getElementById('transferResult').innerHTML = '';
  }, 3000);
  e.target.reset();
});

//make sure to load categories, monthly spending, budgets, transactions, Budget Alerts, and Budgets Summary 
loadCategories();
loadMonthlySpending();
loadCategoryPieChart();
loadBudgets();
loadTransactions();
loadBudgetAlerts();
loadBudgetSummary();