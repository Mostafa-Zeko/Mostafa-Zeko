// Main application JavaScript for Order Management System
const app = Vue.createApp({
    data() {
        return {
            authenticated: false,
            currentUser: null,
            loginForm: { username: '', password: '' },
            loginErrorMessage: '',
            loading: false,
            // User management (admin only)
            users: [],
            userForm: { username: '', password: '', is_admin: false, permissions: {} },
            editingUser: null,
            // Orders data
            orders: [],
            selectedRow: null,
            searchQuery: '',
            searchQuery1: '',
            searchQuery2: '',
            // Remove searchColumn1, searchColumn2
            sortColumn: 'SN Code',
            sortDirection: 'asc',
            undoStack: [],
            columns: [
                "SN Code", "Customer", "Style", "Color", "Print",
                "Fabric", "Fabric Note", "Thread", "Thread Note", 
                "ACC", "ACC Note", "PATTERN", "PATTERN Note", 
                "Sample", "Sample Note", "Date", "Total", 
                "Last Edited Date", "Editor", "Date", "User"
            ],
            // Add homeColumns for the Home (Goods) page
            homeColumns: [
                "Invoice NO", "Supplier", "Date of Shipment", "Date of Arrival", "Type",
                "INV Code", "INV Name", "Customer", "Reef", "Style", "Po.Order", "Color",
                "Special", "Unit", "Quantity", "Actual Rec", "Missing-Over", "Balance",
                "Q.C Status", "Registered SYS", "Stocktaking", "Location", "Alpha#2",
                "Date", "User"
            ],
            // Add balanceColumns for Confirmed Balance page
            balanceColumns: [
                "Invoice NO", "Supplier", "Date of Shipment", "Date of Arrival", "Type",
                "INV Code", "INV Name", "Customer", "Reef", "Style", "Po.Order", "Color",
                "Special", "Unit", "Quantity", "Actual Rec", "Missing-Over", "Balance",
                "Q.C Status", "Registered SYS", "Stocktaking", "Location", "Alpha#2",
                "Date", "User"
            ],
            // Add disbursementColumns for Disbursement Record page
            disbursementColumns: [
                "Invoice NO", "Supplier", "Date of Shipment", "Date of Arrival", "Type",
                "INV Code", "INV Name", "Customer", "Reef", "Style", "Po.Order", "Color",
                "Special", "Unit", "Quantity", "Actual Rec", "Missing-Over", "Balance",
                "Q.C Status", "Registered SYS", "Stocktaking", "Location", "Alpha#2",
                "Date", "User", "Action", "Action User", "Action Time"
            ],
            autoSaveTimer: null,
            autoSaveDelay: 1000,
            pendingChanges: false,
            // Archive
            archive: [],
            showArchive: false,
            columnWidths: {}, // Store column widths by property name
            resizingColumn: null,
            startX: 0,
            startWidth: 0,
            currentPage: 'home', // Track the current page
            // Goods data
            goods: [], // Array to hold goods records
            selectedGoods: [], // Home page selection
            selectedBalance: [], // Confirmed Balance selection
            selectedDisbursement: [], // Add this line to fix undefined error
            disbursementRecords: [], // All disbursement transactions
            disbursementStartDate: '', // For date filter
            disbursementEndDate: '',
            // Permissions for pages and columns
            pageList: [
                { key: 'home', label: 'Home' },
                { key: 'balance', label: 'Confirmed Balance' },
                { key: 'disbursement', label: 'Disbursement Record' }, // New page
                { key: 'report', label: 'Reporting' },
                { key: 'settings', label: 'Settings' },
                { key: 'archive', label: 'Archive' },
                { key: 'dictionary', label: 'Dictionary' } // New admin-only page
            ],
        }
    },
    computed: {
        visibleColumns() {
            return this.columns;
        },
        // Archive columns now match homeColumns
        archiveColumns() {
            return this.homeColumns;
        },
        // Add homeColumns as computed for template use
        homeColumnsComputed() {
            // If you want Date and User in homeColumns, add here as well
            return this.homeColumns;
        },
        // Compute visible columns for Home and Archive based on permissions
        visibleHomeColumns() {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) {
                return this.homeColumns;
            }
            const perms = this.userPermissions?.columns_permissions?.home;
            if (perms) {
                return this.homeColumns.filter(col => perms[col]?.view);
            }
            return this.homeColumns;
        },
        visibleArchiveColumns() {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) {
                return this.archiveColumns;
            }
            const perms = this.userPermissions?.columns_permissions?.archive;
            if (perms) {
                return this.archiveColumns.filter(col => perms[col]?.view);
            }
            return this.archiveColumns;
        },
        visibleBalanceColumns() {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) {
                return this.balanceColumns;
            }
            const perms = this.userPermissions?.columns_permissions?.balance;
            if (perms) {
                return this.balanceColumns.filter(col => perms[col]?.view);
            }
            return this.balanceColumns;
        },
        visibleDisbursementColumns() {
            // Show all columns for now; can add permission logic if needed
            return this.disbursementColumns;
        },
        // Page access permissions
        pagePermissions() {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) {
                return Object.fromEntries(this.pageList.map(p => [p.key, true]));
            }
            return (this.userPermissions && this.userPermissions.pages) ? this.userPermissions.pages : {};
        },
        // Per-page columns permissions (view/edit)
        columnsPermissions() {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) {
                // All columns editable/viewable for all pages
                const perms = {};
                for (const page of this.pageList) {
                    perms[page.key] = {};
                    let cols = [];
                    if (page.key === 'home') cols = this.homeColumns;
                    else if (page.key === 'balance') cols = this.balanceColumns;
                    else if (page.key === 'archive') cols = this.archiveColumns;
                    else cols = [];
                    for (const col of cols) {
                        perms[page.key][col] = { view: true, edit: true };
                    }
                }
                return perms;
            }
            return (this.userPermissions && this.userPermissions.columns_permissions) ? this.userPermissions.columns_permissions : {};
        },
        filteredOrders() {
            if (!this.searchQuery) return this.sortedOrders;
            const query = this.searchQuery.toLowerCase();
            return this.sortedOrders.filter(order => {
                // Only search visible columns for more accurate filtering
                return this.visibleColumns.some(col => {
                    const prop = this.columnToProperty(col);
                    const value = order[prop];
                    if (value === undefined || value === null) return false;
                    return String(value).toLowerCase().includes(query);
                });
            });
        },
        filteredGoods() {
            // For Home page (goods)
            let data = this.goods;
            if (this.currentPage !== 'home') return data;
            if (this.searchQuery1) {
                const q1 = this.searchQuery1.toLowerCase();
                data = data.filter(row =>
                    this.visibleHomeColumns.some(col => {
                        const val = row[this.columnToProperty(col)];
                        return val && String(val).toLowerCase().includes(q1);
                    })
                );
            }
            if (this.searchQuery2) {
                const q2 = this.searchQuery2.toLowerCase();
                data = data.filter(row =>
                    this.visibleHomeColumns.some(col => {
                        const val = row[this.columnToProperty(col)];
                        return val && String(val).toLowerCase().includes(q2);
                    })
                );
            }
            return data;
        },
        sortedOrders() {
            const property = this.columnToProperty(this.sortColumn);
            const direction = this.sortDirection === 'asc' ? 1 : -1;
            return [...this.orders].sort((a, b) => {
                const valueA = a[property] || '';
                const valueB = b[property] || '';
                if (valueA < valueB) return -1 * direction;
                if (valueA > valueB) return 1 * direction;
                return 0;
            });
        },
        canUndo() {
            return this.undoStack.length > 0;
        },
        isAdmin() {
            return this.currentUser && this.currentUser.is_admin;
        },
        userPermissions() {
            if (!this.currentUser) return {};
            if (this.currentUser.permissions === 'all') return { all: true };
            try {
                return typeof this.currentUser.permissions === 'string' ? JSON.parse(this.currentUser.permissions) : this.currentUser.permissions;
            } catch {
                return {};
            }
        },
        showDictionaryPage() {
            return this.isAdmin;
        },
        allGoodsSelected() {
            return this.filteredGoods.length > 0 && this.selectedGoods.length === this.filteredGoods.length;
        },
        allBalanceSelected() {
            return this.filteredOrders.length > 0 && this.selectedBalance.length === this.filteredOrders.length;
        },
        allDisbursementSelected() {
            return this.filteredDisbursementRecords && this.filteredDisbursementRecords.length > 0 &&
                   this.selectedDisbursement.length === this.filteredDisbursementRecords.length;
        },
        filteredDisbursementRecords() {
            // Filter by search and date range
            let data = this.disbursementRecords;
            if (this.disbursementStartDate) {
                data = data.filter(r => r.action_time && r.action_time >= this.disbursementStartDate);
            }
            if (this.disbursementEndDate) {
                data = data.filter(r => r.action_time && r.action_time <= this.disbursementEndDate + ' 23:59:59');
            }
            if (this.searchQuery1) {
                const q1 = this.searchQuery1.toLowerCase();
                data = data.filter(row =>
                    this.visibleDisbursementColumns.some(col => {
                        const val = row[this.columnToProperty(col)];
                        return val && String(val).toLowerCase().includes(q1);
                    })
                );
            }
            if (this.searchQuery2) {
                const q2 = this.searchQuery2.toLowerCase();
                data = data.filter(row =>
                    this.visibleDisbursementColumns.some(col => {
                        const val = row[this.columnToProperty(col)];
                        return val && String(val).toLowerCase().includes(q2);
                    })
                );
            }
            return data;
        }
    },
    methods: {
        // --- AUTH ---
        async checkSession() {
            try {
                const response = await fetch('/api/check-session', { method: 'GET', credentials: 'include' });
                const data = await response.json();
                if (data.authenticated) {
                    this.authenticated = true;
                    this.currentUser = data.user;
                    if (this.isAdmin) this.fetchUsers();
                    this.fetchOrders();
                    this.fetchGoods();
                    this.fetchArchive();
                } else {
                    this.authenticated = false;
                    this.currentUser = null;
                }
            } catch (error) {
                this.authenticated = false;
                this.currentUser = null;
            }
        },
        async login() {
            this.loginErrorMessage = '';
            this.loading = true;
            try {
                const response = await fetch('/api/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    credentials: 'include',
                    body: JSON.stringify(this.loginForm)
                });
                const data = await response.json();
                if (response.ok) {
                    this.authenticated = true;
                    this.currentUser = data.user;
                    if (this.isAdmin) this.fetchUsers();
                    this.fetchOrders();
                    this.fetchGoods();
                    this.fetchArchive();
                } else {
                    this.loginErrorMessage = data.error || 'Login failed';
                }
            } catch (error) {
                this.loginErrorMessage = 'Login failed';
            } finally {
                this.loading = false;
            }
        },
        async logout() {
            await fetch('/api/logout', { method: 'POST', credentials: 'include' });
            this.authenticated = false;
            this.currentUser = null;
            this.orders = [];
            this.goods = [];
            this.archive = [];
            this.selectedRow = null;
        },
        // --- USER MANAGEMENT (admin) ---
        async fetchUsers() {
            if (!this.isAdmin) return;
            const response = await fetch('/api/users', { credentials: 'include' });
            if (response.ok) {
                let users = await response.json();
                users = users.map(u => {
                    try {
                        if (u.permissions === 'all') {
                            u.permissions = { all: true };
                        } else if (typeof u.permissions === 'string') {
                            u.permissions = JSON.parse(u.permissions);
                        }
                        if (!u.permissions) u.permissions = {};
                        // Ensure columns_permissions exists
                        if (!u.permissions.columns_permissions || typeof u.permissions.columns_permissions !== 'object') {
                            u.permissions.columns_permissions = {};
                        }
                    } catch {
                        u.permissions = { columns_permissions: {} };
                    }
                    return u;
                });
                this.users = users;
            } else {
                this.users = [];
            }
        },
        async createUser() {
            if (!this.isAdmin) return;
            if (!this.userForm.permissions.columns_permissions) this.userForm.permissions.columns_permissions = {};
            // Ensure home_columns, archive_columns, balance_columns are present
            if (!this.userForm.permissions.home_columns) this.userForm.permissions.home_columns = {};
            if (!this.userForm.permissions.archive_columns) this.userForm.permissions.archive_columns = {};
            if (!this.userForm.permissions.balance_columns) this.userForm.permissions.balance_columns = {};
            const response = await fetch('/api/users', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify(this.userForm)
            });
            if (response.ok) {
                this.fetchUsers();
                this.userForm = { username: '', password: '', is_admin: false, permissions: {} };
            } else {
                alert('Failed to create user');
            }
        },
        async deleteUser(uid) {
            if (!this.isAdmin) return;
            if (!confirm('Delete this user?')) return;
            const response = await fetch(`/api/users/${uid}`, { method: 'DELETE', credentials: 'include' });
            if (response.ok) this.fetchUsers();
        },
        async updateUser(uid, permissions, is_admin) {
            if (!this.isAdmin) return;
            if (!permissions.columns_permissions || typeof permissions.columns_permissions !== 'object') {
                permissions.columns_permissions = {};
            }
            // Ensure home_columns, archive_columns, balance_columns are objects
            if (!permissions.home_columns || typeof permissions.home_columns !== 'object') {
                permissions.home_columns = {};
            }
            if (!permissions.archive_columns || typeof permissions.archive_columns !== 'object') {
                permissions.archive_columns = {};
            }
            if (!permissions.balance_columns || typeof permissions.balance_columns !== 'object') {
                permissions.balance_columns = {};
            }
            // Ensure new permissions objects exist
            if (!permissions.pages || typeof permissions.pages !== 'object') {
                permissions.pages = {};
            }
            if (!permissions.columns_permissions || typeof permissions.columns_permissions !== 'object') {
                permissions.columns_permissions = {};
            }
            const response = await fetch(`/api/users/${uid}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({ permissions, is_admin })
            });
            if (response.ok) this.fetchUsers();
        },
        // --- ORDERS ---
        async fetchOrders() {
            const response = await fetch('/api/orders', { credentials: 'include' });
            if (response.ok) {
                let orders = await response.json();
                // Defensive: ensure all columns exist on each order and no order is undefined/null
                const defaults = {
                    sn_code: '', customer: '', style: '', color: '', print: '',
                    fabric: '', fabric_note: '', thread: '', thread_note: '', acc: '', acc_note: '', pattern: '', pattern_note: '', sample: '', sample_note: '', date: '', total: '', last_edited_date: '', editor: ''
                };
                orders = (orders || []).filter(o => o && typeof o === 'object').map(order => ({ ...defaults, ...order }));
                this.orders = orders;
            } else {
                this.orders = [];
            }
        },
        async saveChanges(silent = false) {
            if (!this.selectedRow) return;
            let payload;
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) {
                // For admin or all-permission users, always send all fields
                payload = { ...this.selectedRow };
            } else {
                payload = {};
                // IMPORTANT: Find the ORIGINAL order in orders array, NOT the edited selectedRow!
                const orig = this.orders.find(o => o.id === this.selectedRow.id) || {};
                for (const col of Object.keys(this.selectedRow)) {
                    if (this.userPermissions.columns && this.userPermissions.columns[col]) {
                        if (this.selectedRow[col] !== orig[col]) {
                            payload[col] = this.selectedRow[col];
                        }
                    }
                }
                payload.id = this.selectedRow.id;
                if (Object.keys(payload).length === 1) {
                    if (!silent) alert('You have not changed any fields you are allowed to edit.');
                    return;
                }
            }
            // Debug: log payload
            console.log('Saving order payload:', payload);
            try {
                const response = await fetch(`/api/orders/${this.selectedRow.id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    credentials: 'include',
                    body: JSON.stringify(payload)
                });
                if (!response.ok) {
                    const err = await response.json();
                    throw new Error(err.error || 'Failed to save changes');
                }
                const updatedOrder = await response.json();
                const idx = this.orders.findIndex(o => o.id === updatedOrder.id);
                if (idx !== -1) this.orders[idx] = updatedOrder;
                this.pendingChanges = false;
            } catch (error) {
                if (!silent) alert(error.message || 'Failed to save changes.');
            }
        },
        async addRow() {
            if (!this.isAdmin && !this.userPermissions.can_add) {
                alert('No permission to add');
                return;
            }
            this.pushToUndoStack('add');
            const newOrder = {
                sn_code: '', customer: '', style: '', color: '', print: '',
                fabric: '', fabric_note: '', thread: '', thread_note: '', acc: '', acc_note: '', pattern: '', pattern_note: '', sample: '', sample_note: '', date: '', total: '', last_edited_date: new Date().toISOString().slice(0, 19).replace('T', ' '), editor: this.currentUser.username
            };
            try {
                const response = await fetch('/api/orders', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    credentials: 'include',
                    body: JSON.stringify(newOrder)
                });
                if (!response.ok) throw new Error('Failed to add row');
                const createdOrder = await response.json();
                this.orders.push(createdOrder);
                this.selectedRow = createdOrder;
            } catch (error) {
                alert('Failed to add row.');
            }
        },
        async deleteSelectedRow() {
            if (!this.selectedRow) return;
            if (!this.isAdmin && !this.userPermissions.can_delete) {
                alert('No permission to delete');
                return;
            }
            if (!confirm('Are you sure you want to delete this order?')) return;
            this.pushToUndoStack('delete', this.selectedRow);
            try {
                const response = await fetch(`/api/orders/${this.selectedRow.id}`, { method: 'DELETE', credentials: 'include' });
                if (!response.ok) throw new Error('Failed to delete row');
                this.orders = this.orders.filter(o => o.id !== this.selectedRow.id);
                this.selectedRow = null;
            } catch (error) {
                alert('Failed to delete row.');
            }
        },
        // --- ARCHIVE ---
        async fetchArchive() {
            // Use correct endpoint for archived items
            const response = await fetch('/api/archived-items', { credentials: 'include' });
            if (response.ok) {
                let archive = await response.json();
                this.archive = (archive || []).filter(o => o && typeof o === 'object');
            } else {
                this.archive = [];
            }
        },
        async restoreOrder(order) {
            if (!this.isAdmin && !this.userPermissions.can_add) {
                alert('No permission to restore');
                return;
            }
            // Use correct endpoint for restoring archived items
            const response = await fetch(`/api/archived-items/${order.id}/restore`, { method: 'POST', credentials: 'include' });
            if (response.ok) {
                this.fetchOrders();
                this.fetchArchive();
            }
        },
        async deleteArchiveOrder(order) {
            if (!this.isAdmin && !this.userPermissions.can_delete) {
                alert('No permission to delete from archive');
                return;
            }
            if (!confirm('Are you sure you want to permanently delete this archived order?')) return;
            try {
                // Use correct endpoint for deleting archived items
                const response = await fetch(`/api/archived-items/${order.id}`, {
                    method: 'DELETE',
                    credentials: 'include'
                });
                if (!response.ok) throw new Error('Failed to delete archived order');
                this.fetchArchive();
            } catch (error) {
                alert('Failed to delete archived order.');
            }
        },
        // --- GOODS ---
        async fetchGoods() {
            try {
                const response = await fetch('/api/goods', { credentials: 'include' });
                if (response.ok) {
                    this.goods = await response.json();
                } else {
                    this.goods = [];
                }
            } catch (e) {
                this.goods = [];
            }
        },
        addRow() {
            if (this.currentPage !== 'home') return;
            const newGood = {};
            this.homeColumns.forEach(col => {
                newGood[this.columnToProperty(col)] = '';
            });
            newGood['date'] = new Date().toISOString().slice(0, 10);
            newGood['user'] = this.currentUser ? this.currentUser.username : '';
            newGood.id = 'temp_' + Date.now();
            this.goods.push(newGood);
            this.selectedRow = newGood;
        },
        isGoodSelected(good) {
            return this.selectedGoods.some(g => g.id === good.id);
        },
        toggleGoodSelection(good) {
            const idx = this.selectedGoods.findIndex(g => g.id === good.id);
            if (idx === -1) {
                this.selectedGoods.push(good);
            } else {
                this.selectedGoods.splice(idx, 1);
            }
            this.selectedRow = this.selectedGoods.length === 1 ? this.selectedGoods[0] : null;
        },
        toggleSelectAllGoods(event) {
            if (event.target.checked) {
                this.selectedGoods = this.filteredGoods.slice();
            } else {
                this.selectedGoods = [];
            }
            this.selectedRow = this.selectedGoods.length === 1 ? this.selectedGoods[0] : null;
        },
        deleteRow() {
            if (this.currentPage !== 'home' || this.selectedGoods.length === 0) return;
            this.selectedGoods.forEach(good => {
                const idx = this.goods.findIndex(g => g.id === good.id);
                if (idx !== -1) this.goods.splice(idx, 1);
            });
            this.selectedGoods = [];
            this.selectedRow = null;
        },
        confirmReceipt() {
            if (this.currentPage !== 'home' || this.selectedGoods.length === 0) return;
            this.selectedGoods.forEach(good => {
                const confirmed = { ...good };
                confirmed.id = 'balance_' + Date.now() + Math.random();
                this.orders.push(confirmed);
                const idx = this.goods.findIndex(g => g.id === good.id);
                if (idx !== -1) this.goods.splice(idx, 1);
            });
            this.selectedGoods = [];
            this.selectedRow = null;
        },
        exportGoodsToExcel() {
            const XLSX = window.XLSX;
            if (!XLSX) return alert('Excel export not available.');
            const data = this.goods.map(good => {
                const obj = {};
                this.homeColumns.forEach(col => {
                    obj[col] = good[this.columnToProperty(col)];
                });
                return obj;
            });
            const worksheet = XLSX.utils.json_to_sheet(data);
            const workbook = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(workbook, worksheet, 'Goods');
            XLSX.writeFile(workbook, 'goods_export.xlsx');
        },
        triggerImportExcel() {
            this.$refs.importFile.click();
        },
        handleImportExcel(event) {
            const file = event.target.files[0];
            if (!file) return;
            const reader = new FileReader();
            reader.onload = (e) => {
                const data = new Uint8Array(e.target.result);
                const workbook = window.XLSX.read(data, { type: 'array' });
                const sheetName = workbook.SheetNames[0];
                const sheet = workbook.Sheets[sheetName];
                const json = window.XLSX.utils.sheet_to_json(sheet, { header: 1 });
                if (!json.length) return;
                const headers = json[0];
                const rows = json.slice(1).filter(row => row.some(cell => cell !== undefined && cell !== null && cell !== ''));
                // Clear the file (not possible to clear file on disk, but we clear the input)
                event.target.value = '';
                // Add rows to goods
                rows.forEach(rowArr => {
                    const obj = {};
                    headers.forEach((header, idx) => {
                        const prop = this.columnToProperty(header);
                        obj[prop] = rowArr[idx] !== undefined ? rowArr[idx] : '';
                    });
                    obj.id = 'temp_' + Date.now() + Math.random();
                    this.goods.push(obj);
                });
            };
            reader.readAsArrayBuffer(file);
        },
        // --- UI ---
        selectRow(order) {
            if (this.pendingChanges && this.selectedRow) {
                this.saveChanges(true);
            }
            if (this.selectedRow && this.selectedRow.id !== order.id) {
                this.pushToUndoStack('edit', this.selectedRow);
            }
            // Make a DEEP COPY so editing does NOT update the main orders array
            this.selectedRow = JSON.parse(JSON.stringify(order));
        },
        handleInputChange() {
            this.pendingChanges = true;
            if (this.autoSaveTimer) {
                clearTimeout(this.autoSaveTimer);
            }
            this.autoSaveTimer = setTimeout(() => {
                this.saveChanges(true);
            }, this.autoSaveDelay);
            // DO NOT update main orders array here!
        },
        handleInputBlur() {
            if (this.pendingChanges) {
                this.saveChanges();
            }
        },
        sortBy(column) {
            if (this.sortColumn === column) {
                this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortColumn = column;
                this.sortDirection = 'asc';
            }
        },
        clearFilters() {
            this.searchQuery1 = '';
            this.searchQuery2 = '';
        },
        exportData() {
            this.exportToExcel(this.orders, 'orders_export.xlsx');
        },
        exportToExcel(data, filename) {
            const XLSX = window.XLSX;
            if (!XLSX) return alert('Excel export not available.');
            const worksheet = XLSX.utils.json_to_sheet(data.map(order => {
                const obj = {};
                this.columns.forEach(col => {
                    obj[col] = order[this.columnToProperty(col)];
                });
                return obj;
            }));
            const workbook = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(workbook, worksheet, 'Orders');
            XLSX.writeFile(workbook, filename);
        },
        exportToJson(data, filename) {
            const dataStr = JSON.stringify(data, null, 2);
            const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
            const linkElement = document.createElement('a');
            linkElement.setAttribute('href', dataUri);
            linkElement.setAttribute('download', filename);
            linkElement.click();
        },
        pushToUndoStack(action, data = null) {
            this.undoStack.push({
                action,
                data: data ? JSON.parse(JSON.stringify(data)) : null,
                orders: JSON.parse(JSON.stringify(this.orders))
            });
            if (this.undoStack.length > 10) this.undoStack.shift();
        },
        undo() {
            if (!this.canUndo) return;
            const lastAction = this.undoStack.pop();
            if (lastAction.action === 'edit' || lastAction.action === 'delete' || lastAction.action === 'add') {
                this.orders = lastAction.orders;
                this.selectedRow = null;
            }
        },
        isEditable(column) {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) return true;
            // Determine current page
            let pageKey = this.currentPage;
            // Check columns_permissions for this page/column
            const perms = this.userPermissions?.columns_permissions?.[pageKey]?.[column];
            return perms && perms.edit;
        },
        canEditRow(row) {
            if (this.isAdmin || (this.userPermissions && this.userPermissions.all)) return true;
            let pageKey = this.currentPage;
            const perms = this.userPermissions?.columns_permissions?.[pageKey];
            if (!perms) return false;
            return Object.keys(row).some(col => perms[col]?.edit);
        },
        columnToProperty(column) {
            const map = {
                "SN Code": "sn_code",
                "Customer": "customer",
                "Style": "style",
                "Color": "color",
                "Print": "print",
                "Fabric": "fabric",
                "Fabric Note": "fabric_note",
                "Thread": "thread",
                "Thread Note": "thread_note",
                "ACC": "acc",
                "ACC Note": "acc_note",
                "PATTERN": "pattern",
                "PATTERN Note": "pattern_note",
                "Sample": "sample",
                "Sample Note": "sample_note",
                "Date": "date",
                "Total": "total",
                "Last Edited Date": "last_edited_date",
                "Editor": "editor",
                // Home columns mapping
                "Invoice NO": "invoice_no",
                "Supplier": "supplier",
                "Date of Shipment": "date_of_shipment",
                "Date of Arrival": "date_of_arrival",
                "Type": "type",
                "INV Code": "inv_code",
                "INV Name": "inv_name",
                "Reef": "reef",
                "Po.Order": "po_order",
                "Special": "special",
                "Unit": "unit",
                "Quantity": "quantity",
                "Actual Rec": "actual_rec",
                "Missing-Over": "missing_over",
                "Balance": "balance",
                "Q.C Status": "qc_status",
                "Registered SYS": "registered_sys",
                "Stocktaking": "stocktaking",
                "Location": "location",
                "Alpha#2": "alpha2",
                "User": "user", // Add User mapping
                "Action": "action",
                "Action User": "action_user",
                "Action Time": "action_time"
            };
            return map[column] || column.toLowerCase().replace(/ /g, '_');
        },
        startResize(column, event) {
            this.resizingColumn = column;
            this.startX = event.clientX;
            const prop = this.columnToProperty(column);
            const th = event.target.closest('th');
            this.startWidth = th ? th.offsetWidth : (this.columnWidths[prop] || 120);
            if (th) th.classList.add('resizing');
            document.body.style.cursor = 'col-resize';
            document.body.classList.add('no-select');
            document.addEventListener('mousemove', this.onResize);
            document.addEventListener('mouseup', this.stopResize);
        },
        onResize(event) {
            if (!this.resizingColumn) return;
            const prop = this.columnToProperty(this.resizingColumn);
            const delta = event.clientX - this.startX;
            let newWidth = this.startWidth + delta;
            if (newWidth < 60) newWidth = 60;
            if (newWidth > 600) newWidth = 600;
            this.columnWidths[prop] = newWidth;
            // Save per user
            const key = 'columnWidths_' + (this.currentUser?.username || 'default');
            localStorage.setItem(key, JSON.stringify(this.columnWidths));
        },
        stopResize() {
            const ths = document.querySelectorAll('th');
            ths.forEach(th => th.classList.remove('resizing'));
            document.body.style.cursor = '';
            document.body.classList.remove('no-select');
            this.resizingColumn = null;
            document.removeEventListener('mousemove', this.onResize);
            document.removeEventListener('mouseup', this.stopResize);
            const key = 'columnWidths_' + (this.currentUser?.username || 'default');
            localStorage.setItem(key, JSON.stringify(this.columnWidths));
        },
        switchPage(page) {
            this.currentPage = page;
            // Fetch data for the selected page
            if (page === 'archive') this.fetchArchive();
            if (page === 'home') this.fetchGoods();
            if (page === 'balance' || page === 'disbursement') this.fetchOrders();
        },
        // --- Confirmed Balance selection helpers ---
        isBalanceSelected(order) {
            return this.selectedBalance.some(o => o.id === order.id);
        },
        toggleBalanceSelection(order) {
            const idx = this.selectedBalance.findIndex(o => o.id === order.id);
            if (idx === -1) {
                this.selectedBalance.push(order);
            } else {
                this.selectedBalance.splice(idx, 1);
            }
        },
        toggleSelectAllBalance(event) {
            if (event.target.checked) {
                this.selectedBalance = this.filteredOrders.slice();
            } else {
                this.selectedBalance = [];
            }
        },
        // --- Confirmed Balance actions ---
        disbursementAction() {
            if (this.selectedBalance.length === 0) return;
            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
            this.selectedBalance.forEach(order => {
                const record = {
                    ...order,
                    action: 'Disbursement',
                    action_user: this.currentUser.username,
                    action_time: now,
                    user: this.currentUser.username, // For table display
                    time: now // For table display
                };
                this.disbursementRecords.push(record);
                // Remove from Confirmed Balance
                const idx = this.orders.findIndex(o => o.id === order.id);
                if (idx !== -1) this.orders.splice(idx, 1);
            });
            this.selectedBalance = [];
        },
        returnBalanceAction() {
            if (this.selectedBalance.length === 0) return;
            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
            this.selectedBalance.forEach(order => {
                const record = {
                    ...order,
                    action: 'Return',
                    action_user: this.currentUser.username,
                    action_time: now,
                    user: this.currentUser.username,
                    time: now
                };
                this.disbursementRecords.push(record);
                // Remove from Confirmed Balance
                const idx = this.orders.findIndex(o => o.id === order.id);
                if (idx !== -1) this.orders.splice(idx, 1);
            });
            this.selectedBalance = [];
        },
        returnToHomeAction() {
            if (this.selectedBalance.length === 0) return;
            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
            this.selectedBalance.forEach(order => {
                const record = {
                    ...order,
                    action: 'Return to Home',
                    action_user: this.currentUser.username,
                    action_time: now,
                    user: this.currentUser.username,
                    time: now
                };
                this.disbursementRecords.push(record);
                // Move back to goods
                const good = { ...order };
                good.id = 'home_' + Date.now() + Math.random();
                this.goods.push(good);
                const idx = this.orders.findIndex(o => o.id === order.id);
                if (idx !== -1) this.orders.splice(idx, 1);
            });
            this.selectedBalance = [];
        },
        exportDisbursementToExcel() {
            const XLSX = window.XLSX;
            if (!XLSX) return alert('Excel export not available.');
            const data = this.filteredDisbursementRecords.map(record => {
                const obj = {};
                this.visibleBalanceColumns.forEach(col => {
                    obj[col] = record[this.columnToProperty(col)] || record[col.toLowerCase().replace(/ /g, '_')] || '';
                });
                obj['User'] = record.user || record.action_user || '';
                obj['Time'] = record.time || record.action_time || '';
                return obj;
            });
            const worksheet = XLSX.utils.json_to_sheet(data);
            const workbook = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(workbook, worksheet, 'Disbursement');
            XLSX.writeFile(workbook, 'disbursement_export.xlsx');
        },
        // --- LIFE CYCLE HOOKS ---
        mounted() {
            // Restore column widths per user
            const username = this.currentUser?.username || 'default';
            const key = 'columnWidths_' + username;
            const savedWidths = localStorage.getItem(key);
            if (savedWidths) {
                try {
                    this.columnWidths = JSON.parse(savedWidths);
                } catch {}
            }
            // Restore scroll position
            this.$nextTick(() => {
                const scroll = localStorage.getItem('tableScroll');
                if (scroll) {
                    const el = document.querySelector('.table-responsive');
                    if (el) el.scrollLeft = parseInt(scroll, 10);
                }
                // Save scroll position on scroll
                const el = document.querySelector('.table-responsive');
                if (el) {
                    el.addEventListener('scroll', () => {
                        localStorage.setItem('tableScroll', el.scrollLeft);
                    });
                }
            });
            this.checkSession();
            // Remove duplicate fetchGoods/fetchArchive here, handled in checkSession
        }
}); // <-- Correctly close Vue.createApp

app.mount('#app');
