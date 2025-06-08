from flask import Flask, send_from_directory, request, jsonify, session
import os
import sqlite3
from datetime import datetime
import json
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash

# Create Flask app
app = Flask(__name__, static_folder='static')
CORS(app, supports_credentials=True)
app.secret_key = 'your_secret_key'

DB_PATH = 'orders.db'

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    # Users table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        is_admin INTEGER NOT NULL DEFAULT 0,
        permissions TEXT
    )
    ''')
    # Items table (warehouse inventory)
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY,
        item_code TEXT UNIQUE,
        name TEXT,
        description TEXT,
        quantity INTEGER,
        location TEXT,
        last_moved TEXT,
        last_editor TEXT
    )
    ''')
    # Archived items table - create empty with same schema as items
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS archived_items AS SELECT * FROM items WHERE 0
    ''')
    # Goods table for recording goods
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS goods (
        id INTEGER PRIMARY KEY,
        invoice_no TEXT,
        supplier TEXT,
        date_of_shipment TEXT,
        date_of_arrival TEXT,
        type TEXT,
        inv_code TEXT,
        inv_name TEXT,
        customer TEXT,
        reef TEXT,
        style TEXT,
        po_order TEXT,
        color TEXT,
        special TEXT,
        unit TEXT,
        quantity INTEGER,
        actual_rec INTEGER,
        missing_over INTEGER,
        balance INTEGER,
        qc_status TEXT,
        registered_sys TEXT,
        stocktaking TEXT,
        location TEXT,
        alpha2 TEXT
    )
    ''')
    # Add archived_orders table if not exists (for archive endpoints)
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS archived_orders AS SELECT * FROM goods WHERE 0
    ''')
    # Create admin user if not exists
    cursor.execute('SELECT id FROM users WHERE username = ?', ('Mostafa',))
    if not cursor.fetchone():
        cursor.execute('INSERT INTO users (username, password, is_admin, permissions) VALUES (?, ?, ?, ?)',
            ('Mostafa', generate_password_hash('czar2010'), 1, 'all'))
    conn.commit()
    conn.close()

# Initialize database
init_db()

def has_column_permission(user, column):
    if user['is_admin']:
        return True
    perms = user['permissions']
    if isinstance(perms, str):
        if perms == 'all':
            return True
        try:
            perms = json.loads(perms)
        except Exception as e:
            print(f'Error parsing permissions JSON: {e}')
            return False
    if perms == 'all':
        return True
    if not isinstance(perms, dict):
        print(f'Permissions is not a dict: {perms}')
        return False
    columns = perms.get('columns', {})
    if not isinstance(columns, dict):
        print(f'Permissions "columns" key missing or invalid: {columns}')
        return False
    # Accept both {col: {edit: bool, ...}} and {col: true/false} for backward compatibility
    col_perms = columns.get(column)
    if not col_perms and isinstance(column, str):
        col_perms = columns.get(column.lower())
    if not col_perms and isinstance(column, str):
        snake = column.replace(" ", "_").lower()
        col_perms = columns.get(snake)
    if isinstance(col_perms, dict):
        allowed = bool(col_perms.get('edit', False))
    elif isinstance(col_perms, bool):
        allowed = col_perms
    else:
        allowed = False
    print(f'Checking column edit permission for \"{column}\": {allowed}')
    return allowed

def get_permission(user, perm_key):
    if user['is_admin']:
        return True
    perms = user['permissions']
    if isinstance(perms, str):
        if perms == 'all':
            return True
        try:
            perms = json.loads(perms)
        except Exception as e:
            print(f'Error parsing permissions JSON: {e}') # Added error logging
            return False
    if perms == 'all':
        return True
    # Added type checking for robustness
    if not isinstance(perms, dict):
        print(f'Permissions is not a dict: {perms}')
        return False
    allowed = perms.get(perm_key, False)
    # Debug print (optional)
    print(f'Checking permission "{perm_key}": {allowed}') # Added debug print
    return bool(allowed) # Ensure boolean return

@app.route('/js/<path:filename>')
def serve_js(filename):
    return send_from_directory(os.path.join(app.root_path, 'static', 'js'), filename)

@app.route('/css/<path:filename>')
def serve_css(filename):
    return send_from_directory(os.path.join(app.root_path, 'static', 'css'), filename)

@app.route('/favicon.ico')
def favicon():
    return send_from_directory(os.path.join(app.root_path, 'static'), 'favicon.ico', mimetype='image/vnd.microsoft.icon')

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE username = ?', (username,))
    user = cursor.fetchone()
    conn.close()
    if not user or not check_password_hash(user['password'], password):
        return jsonify({'error': 'Invalid credentials'}), 401
    session['user_id'] = user['id']
    return jsonify({'message': 'Login successful', 'user': {
        'id': user['id'],
        'username': user['username'],
        'is_admin': bool(user['is_admin']),
        'permissions': user['permissions']
    }}), 200

@app.route('/api/logout', methods=['POST'])
def logout():
    session.pop('user_id', None)
    return jsonify({'message': 'Logout successful'})

@app.route('/api/check-session', methods=['GET'])
def check_session():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'authenticated': False})
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    conn.close()
    if not user:
        session.pop('user_id', None)
        return jsonify({'authenticated': False})
    return jsonify({'authenticated': True, 'user': {
        'id': user['id'],
        'username': user['username'],
        'is_admin': bool(user['is_admin']),
        'permissions': user['permissions']
    }})

@app.route('/api/users', methods=['GET', 'POST'])
def manage_users():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'error': 'Not authenticated'}), 401
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    if not user or not user['is_admin']:
        conn.close()
        return jsonify({'error': 'Admin only'}), 403
    if request.method == 'GET':
        cursor.execute('SELECT id, username, is_admin, permissions FROM users')
        users = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return jsonify(users)
    if request.method == 'POST':
        data = request.json
        username = data.get('username')
        password = data.get('password')
        is_admin = int(data.get('is_admin', 0))
        # Accept permissions as either {columns: ...} or as permissions directly
        perms_val = data.get('permissions', {})
        columns = perms_val.get('columns', {}) if isinstance(perms_val, dict) else {}
        # Normalize columns to {col: {edit: bool, view: bool}}
        normalized_columns = {}
        if isinstance(columns, dict) and 'edit' in columns and isinstance(columns['edit'], list):
            for col in columns['edit']:
                normalized_columns[col] = {"edit": True, "view": True}
        elif isinstance(columns, list):
            for col in columns:
                normalized_columns[col] = {"edit": True, "view": True}
        elif isinstance(columns, dict):
            for k, v in columns.items():
                if isinstance(v, bool):
                    normalized_columns[k] = {"edit": v, "view": True}
                elif isinstance(v, dict):
                    normalized_columns[k] = {
                        "edit": bool(v.get("edit", False)),
                        "view": bool(v.get("view", True))
                    }
        columns = normalized_columns
        if is_admin:
            permissions = 'all'
        else:
            perms_val['columns'] = columns
            permissions = json.dumps(perms_val)
        if not username or not password:
            conn.close()
            return jsonify({'error': 'Username and password required'}), 400
        try:
            cursor.execute('INSERT INTO users (username, password, is_admin, permissions) VALUES (?, ?, ?, ?)',
                (username, generate_password_hash(password), is_admin, permissions))
            conn.commit()
            conn.close()
            return jsonify({'message': 'User created'}), 201
        except Exception as e:
            conn.rollback()
            conn.close()
            return jsonify({'error': str(e)}), 400

@app.route('/api/users/<int:uid>', methods=['DELETE', 'PUT'])
def user_ops(uid):
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'error': 'Not authenticated'}), 401
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    if not user or not user['is_admin']:
        conn.close()
        return jsonify({'error': 'Admin only'}), 403
    if request.method == 'DELETE':
        cursor.execute('DELETE FROM users WHERE id = ?', (uid,))
        conn.commit()
        conn.close()
        return jsonify({'message': 'User deleted'})
    if request.method == 'PUT':
        data = request.json
        is_admin = int(data.get('is_admin', 0))
        perms_val = data.get('permissions', {})
        columns = perms_val.get('columns', {}) if isinstance(perms_val, dict) else {}
        normalized_columns = {}
        if isinstance(columns, dict) and 'edit' in columns and isinstance(columns['edit'], list):
            for col in columns['edit']:
                normalized_columns[col] = {"edit": True, "view": True}
        elif isinstance(columns, list):
            for col in columns:
                normalized_columns[col] = {"edit": True, "view": True}
        elif isinstance(columns, dict):
            for k, v in columns.items():
                if isinstance(v, bool):
                    normalized_columns[k] = {"edit": v, "view": True}
                elif isinstance(v, dict):
                    normalized_columns[k] = {
                        "edit": bool(v.get("edit", False)),
                        "view": bool(v.get("view", True))
                    }
        columns = normalized_columns
        if is_admin:
            permissions = 'all'
        else:
            perms_val['columns'] = columns
            permissions = json.dumps(perms_val)
        cursor.execute('UPDATE users SET permissions = ?, is_admin = ? WHERE id = ?', (permissions, is_admin, uid))
        conn.commit()
        conn.close()
        return jsonify({'message': 'User updated'})

def get_current_user():
    user_id = session.get('user_id')
    if not user_id:
        return None
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    conn.close()
    return user

@app.route('/api/items', methods=['GET'])
def get_items():
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM items')
    items = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(items), 200

@app.route('/api/items', methods=['POST'])
def create_item():
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    if not (user['is_admin'] or get_permission(user, 'can_add')):
        return jsonify({'error': 'No permission to add'}), 403
    data = request.json
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    data['last_moved'] = now
    data['last_editor'] = user['username']
    try:
        columns = ', '.join([key for key in data.keys()])
        placeholders = ', '.join(['?' for _ in data.keys()])
        values = list(data.values())
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute(f'INSERT INTO items ({columns}) VALUES ({placeholders})', values)
        item_id = cursor.lastrowid
        conn.commit()
        cursor.execute('SELECT * FROM items WHERE id = ?', (item_id,))
        item = dict(cursor.fetchone())
        conn.close()
        return jsonify(item), 201
    except Exception as e:
        conn.rollback()
        conn.close()
        return jsonify({'error': f'Failed to create item: {str(e)}'}), 500

@app.route('/api/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    data = request.json
    editable_fields = {}
    for col, val in data.items():
        if col in ['id']:
            continue
        if has_column_permission(user, col):
            editable_fields[col] = val
        elif has_column_permission(user, col.lower()):
            editable_fields[col.lower()] = val
        else:
            snake = col.replace(" ", "_").lower()
            if has_column_permission(user, snake):
                editable_fields[snake] = val
    if not editable_fields:
        return jsonify({'error': 'You have not changed any fields you are allowed to edit.'}), 403
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    editable_fields['last_moved'] = now
    editable_fields['last_editor'] = user['username']
    set_clause = ', '.join([f'{key} = ?' for key in editable_fields.keys()])
    values = list(editable_fields.values()) + [item_id]
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM items WHERE id = ?', (item_id,))
    item = cursor.fetchone()
    if not item:
        conn.close()
        return jsonify({'error': 'Item not found'}), 404
    cursor.execute(f'UPDATE items SET {set_clause} WHERE id = ?', values)
    conn.commit()
    cursor.execute('SELECT * FROM items WHERE id = ?', (item_id,))
    updated_item = dict(cursor.fetchone())
    conn.close()
    return jsonify(updated_item), 200

@app.route('/api/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    if not (user['is_admin'] or get_permission(user, 'can_delete')):
        return jsonify({'error': 'No permission to delete'}), 403
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM items WHERE id = ?', (item_id,))
    item = cursor.fetchone()
    if not item:
        conn.close()
        return jsonify({'error': 'Item not found'}), 404
    cursor.execute('INSERT INTO archived_items SELECT * FROM items WHERE id = ?', (item_id,))
    cursor.execute('DELETE FROM items WHERE id = ?', (item_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': 'Item deleted and archived'}), 200

@app.route('/api/archived-items', methods=['GET'])
def get_archived_items():
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM archived_items')
    items = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(items), 200

@app.route('/api/archived-items/<int:item_id>/restore', methods=['POST'])
def restore_archived_item(item_id):
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    if not (user['is_admin'] or get_permission(user, 'can_add')):
        return jsonify({'error': 'No permission to restore'}), 403
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM archived_items WHERE id = ?', (item_id,))
    item = cursor.fetchone()
    if not item:
        conn.close()
        return jsonify({'error': 'Archived item not found'}), 404
    columns = [desc[0] for desc in cursor.description]
    values = [item[c] for c in columns]
    cursor.execute(f'INSERT INTO items ({", ".join(columns)}) VALUES ({", ".join(["?" for _ in columns])})', values)
    cursor.execute('DELETE FROM archived_items WHERE id = ?', (item_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': 'Item restored'}), 200

@app.route('/api/archived-items/<int:item_id>', methods=['DELETE'])
def delete_from_archived_items(item_id):
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    if not (user['is_admin'] or get_permission(user, 'can_delete')):
        return jsonify({'error': 'No permission to delete from archive'}), 403
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM archived_items WHERE id = ?', (item_id,))
    item = cursor.fetchone()
    if not item:
        conn.close()
        return jsonify({'error': 'Archived item not found'}), 404
    cursor.execute('DELETE FROM archived_items WHERE id = ?', (item_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': 'Archived item deleted'}), 200

@app.route('/api/debug/users')
def debug_users():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT id, username, is_admin, permissions FROM users')
    users = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(users)

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def catch_all(path):
    if path.startswith('api/'):
        return jsonify({'error': 'Not found'}), 404
    return send_from_directory('static', 'index.html')

@app.route('/api/archive/<int:order_id>', methods=['DELETE'])
def delete_from_archive(order_id):
    user = get_current_user()
    if not user:
        return jsonify({'error': 'Not authenticated'}), 401
    if not (user['is_admin'] or get_permission(user, 'can_delete')):
        return jsonify({'error': 'No permission to delete from archive'}), 403
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    # Defensive: ensure table exists
    try:
        cursor.execute('SELECT * FROM archived_orders WHERE id = ?', (order_id,))
    except sqlite3.OperationalError as e:
        conn.close()
        return jsonify({'error': f'archived_orders table missing: {e}'}), 500
    order = cursor.fetchone()
    if not order:
        conn.close()
        return jsonify({'error': 'Archived order not found'}), 404
    cursor.execute('DELETE FROM archived_orders WHERE id = ?', (order_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': 'Archived order deleted'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)

