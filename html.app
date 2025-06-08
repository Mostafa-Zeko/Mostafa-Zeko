<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Order Management System</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/css/style.css">
    <link rel="icon" href="data:,">
</head>
<body>
    <div id="app">
        <!-- Login Form -->
        <div v-if="!authenticated" class="login-bg">
            <div class="container mt-5">
                <div class="row justify-content-center">
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-header bg-primary text-white text-center">
                                <h4>Login</h4>
                            </div>
                            <div class="card-body">
                                <div v-if="loginErrorMessage" class="alert alert-danger">
                                    {{ loginErrorMessage }}
                                </div>
                                <form @submit.prevent="login">
                                    <div class="mb-3">
                                        <label for="username" class="form-label">Username:</label>
                                        <input type="text" id="username" v-model="loginForm.username" class="form-control" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="password" class="form-label">Password:</label>
                                        <input type="password" id="password" v-model="loginForm.password" class="form-control" required>
                                    </div>
                                    <div class="d-grid">
                                        <button type="submit" class="btn btn-primary">
                                            <span v-if="loading" class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
                                            Login
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <!-- Main Application -->
        <div v-if="authenticated" class="container-fluid">
            <!-- Navigation Bar -->
            <nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-3">
                <div class="container-fluid">
                    <span class="navbar-brand">Warehouse Management - {{ currentUser.username }} <span v-if="isAdmin">(Admin)</span></span>
                    <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                        <li class="nav-item">
                            <a class="nav-link" :class="{active: currentPage==='home'}" href="#" @click.prevent="switchPage('home')">Home</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" :class="{active: currentPage==='balance'}" href="#" @click.prevent="switchPage('balance')">Confirmed Balance</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" :class="{active: currentPage==='report'}" href="#" @click.prevent="switchPage('report')">Reporting</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" :class="{active: currentPage==='settings'}" href="#" @click.prevent="switchPage('settings')">Settings</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" :class="{active: currentPage==='archive'}" href="#" @click.prevent="switchPage('archive')">Archive</a>
                        </li>
                        <li class="nav-item" v-if="showDictionaryPage">
                            <a class="nav-link" :class="{active: currentPage==='dictionary'}" href="#" @click.prevent="switchPage('dictionary')">Dictionary</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" :class="{active: currentPage==='disbursement'}" href="#" @click.prevent="switchPage('disbursement')">Disbursement Record</a>
                        </li>
                    </ul>
                    <button @click="logout" class="btn btn-outline-light">Logout</button>
                </div>
            </nav>
            <!-- Home Page: Preparing for Receipt -->
            <div v-show="currentPage==='home'">
                <h2 class="mb-3">Preparing for Receipt</h2>
                <!-- Action Buttons Row -->
                <div class="mb-3 d-flex flex-wrap gap-2">
                    <button class="btn btn-success btn-sm" @click="addRow">Add Row</button>
                    <button class="btn btn-danger btn-sm" @click="deleteRow" :disabled="selectedGoods.length === 0">Delete Row</button>
                    <button class="btn btn-primary btn-sm" @click="confirmReceipt" :disabled="selectedGoods.length === 0">Confirm Receipt</button>
                    <button class="btn btn-warning btn-sm" @click="returnToSupplier" :disabled="!selectedRow">Return to Supplier</button>
                    <button class="btn btn-secondary btn-sm" @click="notReceived" :disabled="!selectedRow">Not Received</button>
                    <button class="btn btn-outline-success btn-sm" @click="exportGoodsToExcel">Export to Excel</button>
                    <button class="btn btn-info btn-sm" @click="triggerImportExcel">Import from Excel</button>
                    <input type="file" ref="importFile" style="display:none" @change="handleImportExcel" accept=".xlsx,.xls" />
                </div>
                <!-- Two search boxes (no column selectors) -->
                <div class="row mb-2">
                    <div class="col-md-6">
                        <input v-model="searchQuery1" class="form-control form-control-sm" placeholder="Search in all columns">
                    </div>
                    <div class="col-md-6">
                        <input v-model="searchQuery2" class="form-control form-control-sm" placeholder="Further filter in all columns">
                    </div>
                </div>
                <!-- Goods Table -->
                <div class="table-responsive">
                    <table class="table table-striped table-bordered">
                        <thead class="table-dark">
                            <tr>
                                <th>
                                    <input type="checkbox" @change="toggleSelectAllGoods($event)" :checked="allGoodsSelected">
                                </th>
                                <th v-for="col in visibleHomeColumns" :key="col">{{ col }}</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="good in filteredGoods" :key="good.id" :class="{ 'table-active': isGoodSelected(good) }">
                                <td>
                                    <input type="checkbox" :checked="isGoodSelected(good)" @change="toggleGoodSelection(good)">
                                </td>
                                <td v-for="col in visibleHomeColumns" :key="col">{{ good[columnToProperty(col)] }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <!-- Confirmed Balance Page -->
            <div v-show="currentPage==='balance'">
                <h2 class="mb-3">Confirmed Balance</h2>
                <!-- Action Buttons Row for Confirmed Balance -->
                <div class="mb-3 d-flex flex-wrap gap-2">
                    <button class="btn btn-primary btn-sm" @click="disbursementAction" :disabled="selectedBalance.length === 0">Disbursement</button>
                    <button class="btn btn-warning btn-sm" @click="returnBalanceAction" :disabled="selectedBalance.length === 0">Return</button>
                    <button class="btn btn-secondary btn-sm" @click="returnToHomeAction" :disabled="selectedBalance.length === 0">Return to Home</button>
                    <button class="btn btn-info btn-sm" @click="allocationQtyAction" :disabled="selectedBalance.length === 0">Allocation QTY</button>
                </div>
                <!-- Two search boxes (no column selectors) -->
                <div class="row mb-2">
                    <div class="col-md-6">
                        <input v-model="searchQuery1" class="form-control form-control-sm" placeholder="Search in all columns">
                    </div>
                    <div class="col-md-6">
                        <input v-model="searchQuery2" class="form-control form-control-sm" placeholder="Further filter in all columns">
                    </div>
                </div>
                <div class="table-responsive">
                    <table class="table table-striped table-bordered">
                        <thead class="table-dark">
                            <tr>
                                <th>
                                    <input type="checkbox" @change="toggleSelectAllBalance($event)" :checked="allBalanceSelected">
                                </th>
                                <th v-for="col in visibleBalanceColumns" :key="col">{{ col }}</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="order in filteredOrders" :key="order.id" :class="{ 'table-active': isBalanceSelected(order) }">
                                <td>
                                    <input type="checkbox" :checked="isBalanceSelected(order)" @change="toggleBalanceSelection(order)">
                                </td>
                                <td v-for="col in visibleBalanceColumns" :key="col">{{ order[columnToProperty(col)] }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <!-- Disbursement Record Page (copy of Confirmed Balance, but use visibleDisbursementColumns) -->
            <div v-show="currentPage==='disbursement'">
                <h2 class="mb-3">Disbursement Record</h2>
                <!-- Action Buttons Row for Disbursement Record -->
                <div class="mb-3 d-flex flex-wrap gap-2">
                    <button class="btn btn-primary btn-sm" @click="disbursementRecordAction" :disabled="selectedDisbursement.length === 0">Disbursement</button>
                    <button class="btn btn-warning btn-sm" @click="returnDisbursementAction" :disabled="selectedDisbursement.length === 0">Return</button>
                    <button class="btn btn-secondary btn-sm" @click="returnDisbursementToHomeAction" :disabled="selectedDisbursement.length === 0">Return to Home</button>
                    <input type="date" v-model="disbursementStartDate" class="form-control form-control-sm" style="width:auto;display:inline-block;">
                    <input type="date" v-model="disbursementEndDate" class="form-control form-control-sm" style="width:auto;display:inline-block;">
                    <button class="btn btn-outline-success btn-sm" @click="exportDisbursementToExcel">Export to Excel</button>
                </div>
                <div class="row mb-2">
                    <div class="col-md-6">
                        <input v-model="searchQuery1" class="form-control form-control-sm" placeholder="Search in all columns">
                    </div>
                    <div class="col-md-6">
                        <input v-model="searchQuery2" class="form-control form-control-sm" placeholder="Further filter in all columns">
                    </div>
                </div>
                <div class="table-responsive">
                    <table class="table table-striped table-bordered">
                        <thead class="table-dark">
                            <tr>
                                <th>
                                    <input type="checkbox" @change="toggleSelectAllDisbursement($event)" :checked="allDisbursementSelected">
                                </th>
                                <th v-for="col in visibleBalanceColumns" :key="col">{{ col }}</th>
                                <th>User</th>
                                <th>Time</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="record in filteredDisbursementRecords" :key="record.id + '-' + record.time" :class="{ 'table-active': isDisbursementSelected(record) }">
                                <td>
                                    <input type="checkbox" :checked="isDisbursementSelected(record)" @change="toggleDisbursementSelection(record)">
                                </td>
                                <td v-for="col in visibleBalanceColumns" :key="col">{{ record[columnToProperty(col)] }}</td>
                                <td>{{ record.user }}</td>
                                <td>{{ record.time }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <!-- Reporting Page -->
            <div v-show="currentPage==='report'">
                <h2 class="mb-3">Reporting</h2>
                <!-- Add your reporting logic here -->
                <p>Generate and view warehouse reports.</p>
            </div>
            <!-- Settings Page -->
            <div v-show="currentPage==='settings'">
                <h2 class="mb-3">Settings</h2>
                <!-- Add your settings logic here -->
                <p>Manage user accounts, permissions, and other settings.</p>
                <div v-if="isAdmin">
                    <!-- User Management Section (already present) -->
                    <div class="card">
                        <div class="card-header bg-secondary text-white">User Management</div>
                        <div class="card-body">
                            <form @submit.prevent="createUser" class="row g-2 align-items-end">
                                <div class="col-md-3">
                                    <input v-model="userForm.username" class="form-control" placeholder="Username" required>
                                </div>
                                <div class="col-md-3">
                                    <input v-model="userForm.password" class="form-control" placeholder="Password" required>
                                </div>
                                <div class="col-md-2">
                                    <label><input type="checkbox" v-model="userForm.is_admin"> Admin</label>
                                </div>
                                <div class="col-md-2">
                                    <button class="btn btn-success" type="submit">Create User</button>
                                </div>
                            </form>
                            <table class="table table-bordered table-sm mt-3">
                                <thead><tr><th>Username</th><th>Admin</th><th>Permissions</th><th>Delete</th></tr></thead>
                                <tbody>
                                    <tr v-for="user in users" :key="user.id">
                                        <td>{{ user.username }}</td>
                                        <td>
                                          <input type="checkbox" :checked="user.is_admin" @change="updateUser(user.id, user.permissions, $event.target.checked ? 1 : 0)">
                                        </td>
                                        <td>
                                            <details>
                                                <summary>Edit</summary>
                                                <div class="mb-2"><strong>Page Permissions</strong></div>
                                                <div v-for="page in pageList" :key="'page-' + page.key">
                                                    <label>
                                                        <input type="checkbox"
                                                            :checked="user.permissions.pages && user.permissions.pages[page.key]"
                                                            @change="e => {
                                                                if (!user.permissions.pages) user.permissions.pages = {};
                                                                user.permissions.pages[page.key] = e.target.checked;
                                                                updateUser(user.id, user.permissions, user.is_admin);
                                                            }"
                                                        >
                                                        {{ page.label }}
                                                    </label>
                                                </div>
                                                <div class="mb-2 mt-3"><strong>Per-Page Columns Permissions</strong></div>
                                                <div v-for="page in pageList" :key="'colperm-' + page.key" class="mb-3">
                                                    <div><strong>{{ page.label }}</strong></div>
                                                    <table class="table table-bordered table-sm align-middle" style="width:auto;min-width:350px;">
                                                        <thead>
                                                            <tr>
                                                                <th style="min-width:120px;">Column</th>
                                                                <th style="width:60px;">Edit</th>
                                                                <th style="width:60px;">View</th>
                                                            </tr>
                                                        </thead>
                                                        <tbody>
                                                            <tr v-for="col in (
                                                                page.key === 'home' ? homeColumnsComputed :
                                                                page.key === 'balance' ? balanceColumns :
                                                                page.key === 'archive' ? archiveColumns :
                                                                page.key === 'disbursement' ? disbursementColumns :
                                                                []
                                                            )" :key="page.key + '-' + col">
                                                                <td>{{ col }}</td>
                                                                <td class="text-center">
                                                                    <input type="checkbox"
                                                                        :checked="user.permissions.columns_permissions && user.permissions.columns_permissions[page.key] && user.permissions.columns_permissions[page.key][col] && user.permissions.columns_permissions[page.key][col].edit"
                                                                        @change="e => {
                                                                            if (!user.permissions.columns_permissions) user.permissions.columns_permissions = {};
                                                                            if (!user.permissions.columns_permissions[page.key]) user.permissions.columns_permissions[page.key] = {};
                                                                            if (!user.permissions.columns_permissions[page.key][col]) user.permissions.columns_permissions[page.key][col] = {view: false, edit: false};
                                                                            user.permissions.columns_permissions[page.key][col].edit = e.target.checked;
                                                                            updateUser(user.id, user.permissions, user.is_admin);
                                                                        }"
                                                                    >
                                                                </td>
                                                                <td class="text-center">
                                                                    <input type="checkbox"
                                                                        :checked="user.permissions.columns_permissions && user.permissions.columns_permissions[page.key] && user.permissions.columns_permissions[page.key][col] && user.permissions.columns_permissions[page.key][col].view"
                                                                        @change="e => {
                                                                            if (!user.permissions.columns_permissions) user.permissions.columns_permissions = {};
                                                                            if (!user.permissions.columns_permissions[page.key]) user.permissions.columns_permissions[page.key] = {};
                                                                            if (!user.permissions.columns_permissions[page.key][col]) user.permissions.columns_permissions[page.key][col] = {view: false, edit: false};
                                                                            user.permissions.columns_permissions[page.key][col].view = e.target.checked;
                                                                            updateUser(user.id, user.permissions, user.is_admin);
                                                                        }"
                                                                    >
                                                                </td>
                                                            </tr>
                                                        </tbody>
                                                    </table>
                                                </div>
                                                <div class="mt-2">
                                                    <label>
                                                        <input type="checkbox" v-model="user.permissions.can_add" @change="updateUser(user.id, user.permissions, user.is_admin)"> Add
                                                    </label>
                                                    <label>
                                                        <input type="checkbox" v-model="user.permissions.can_delete" @change="updateUser(user.id, user.permissions, user.is_admin)"> Delete
                                                    </label>
                                                </div>
                                            </details>
                                        </td>
                                        <td><button class="btn btn-danger btn-sm" @click="deleteUser(user.id)">Delete</button></td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <!-- Archive Page -->
            <div v-show="currentPage==='archive'">
                <h2 class="mb-3">Archive</h2>
                <!-- Two search boxes (no column selectors) -->
                <div class="row mb-2">
                    <div class="col-md-6">
                        <input v-model="searchQuery1" class="form-control form-control-sm" placeholder="Search in all columns">
                    </div>
                    <div class="col-md-6">
                        <input v-model="searchQuery2" class="form-control form-control-sm" placeholder="Further filter in all columns">
                    </div>
                </div>
                <div class="table-responsive">
                    <table class="table table-striped table-bordered">
                        <thead class="table-dark">
                            <tr>
                                <th v-for="col in visibleArchiveColumns" :key="col">{{ col }}</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="order in filteredOrders" :key="order.id">
                                <td v-for="col in visibleArchiveColumns" :key="col">{{ order[columnToProperty(col)] }}</td>
                                <td>
                                    <button class="btn btn-success btn-sm me-1" @click="restoreOrder(order)">Restore</button>
                                    <button class="btn btn-danger btn-sm" @click="deleteArchiveOrder(order)">Delete</button>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <!-- Dictionary Page (Admin Only) -->
            <div v-if="showDictionaryPage && currentPage==='dictionary'">
                <h2 class="mb-3">Dictionary (Admin Only)</h2>
                <div class="table-responsive">
                    <table class="table table-bordered table-striped">
                        <thead class="table-dark">
                            <tr>
                                <th>Column Name</th>
                                <th>Possible Values / Words</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="col in homeColumnsComputed" :key="col">
                                <td>{{ col }}</td>
                                <td><!-- Placeholder: Add/edit possible values for this column here --></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <p class="text-muted mt-2">This page is for admins to prepare and manage the list of words/values used in each column across all pages.</p>
            </div>
        </div>
    </div>
    <!-- Professional Signature Footer -->
    <footer class="signature-footer text-center py-3">
        <span id="signature-footer">
            &copy; <span id="footer-year"></span>
            <strong>Mostafa Zakaria</strong>
            &mdash;
            <a href="https://github.com/Mostafa-Zeko" target="_blank" rel="noopener" style="color:#2563eb;text-decoration:underline;">
                github.com/Mostafa-Zeko
            </a>
        </span>
    </footer>
    <script src="https://cdn.jsdelivr.net/npm/vue@3.3.4/dist/vue.global.prod.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
    <script src="/js/app.js"></script>
    <script>
        // Set the current year in the signature footer
        document.addEventListener('DOMContentLoaded', function() {
            var yearSpan = document.getElementById('footer-year');
            if (yearSpan) yearSpan.textContent = new Date().getFullYear();
        });
    </script>
</body>
</html>
