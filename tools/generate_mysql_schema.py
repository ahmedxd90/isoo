import json
from pathlib import Path

src = Path('/home/ubuntu/.mcp/tool-results/2026-09-18_10-18-35.254016163_supabase_list_tables_881d3665.json')
out = Path('/home/ubuntu/isoo/mysql_clean_schema.sql')
data = json.loads(src.read_text())

def sql_type(c):
    t = c.get('data_type', 'text')
    if t == 'uuid': return 'char(36)'
    if t in ('text', 'USER-DEFINED'):
        if 'unique' in c.get('options', []) or c.get('name','').endswith('_id') or c.get('name') in ('username','email','type','status','role','admin_role'):
            return 'varchar(255)'
        return 'longtext'
    if t == 'bigint': return 'bigint'
    if t == 'integer': return 'int'
    if t == 'numeric': return 'decimal(20,6)'
    if t == 'boolean': return 'tinyint(1)'
    if t == 'timestamp with time zone': return 'timestamp'
    if t == 'timestamp without time zone': return 'timestamp'
    if t == 'jsonb': return 'longtext'
    if t == 'date': return 'date'
    if t == 'time without time zone': return 'time'
    return 'longtext'

lines = [
    '-- SAKI clean MariaDB schema generated from the Supabase public schema.',
    '-- No historical data is included. IDs and relationships are kept compatible.',
    'SET NAMES utf8mb4;',
    'SET FOREIGN_KEY_CHECKS=0;',
]
for table in data['tables']:
    name = table['name'].split('.')[-1]
    cols = table.get('columns', [])
    pks = table.get('primary_keys', [])
    definitions = []
    unique_cols = []
    for c in cols:
        n = c['name']
        nullable = 'NULL' if 'nullable' in c.get('options', []) else 'NOT NULL'
        default = ''
        typ = sql_type(c)
        if n in pks and typ == 'longtext':
            typ = 'varchar(255)'
        auto_increment = n in pks and len(pks) == 1 and typ in ('int', 'bigint')
        if auto_increment:
            nullable = 'NOT NULL'
            default = 'AUTO_INCREMENT'
        if nullable == 'NULL': default = 'DEFAULT NULL'
        elif not auto_increment and typ in ('tinyint(1)', 'int', 'bigint', 'decimal(20,6)'):
            default = 'DEFAULT 0'
        elif typ in ('longtext',): default = ''
        definitions.append(f'  `{n}` {typ} {nullable} {default}'.strip())
        if 'unique' in c.get('options', []) and n not in pks: unique_cols.append(n)
    if pks: definitions.append('  PRIMARY KEY (' + ', '.join(f'`{x}`' for x in pks) + ')')
    for u in unique_cols: definitions.append(f'  UNIQUE KEY `uq_{name}_{u}` (`{u}`)')
    # Add practical indexes for common foreign-key-like columns without imposing FK order.
    indexed = set(pks + unique_cols)
    for c in cols:
        n = c['name']
        if n.endswith('_id') and n not in indexed:
            index_expr = f'`{n}`(36)' if sql_type(c) in ('longtext', 'varchar(255)') else f'`{n}`'
            definitions.append(f'  KEY `idx_{name}_{n}` ({index_expr})')
    lines.append(f'CREATE TABLE IF NOT EXISTS `{name}` (\n' + ',\n'.join(definitions) + '\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;')
lines.extend([
    "CREATE TABLE IF NOT EXISTS `auth_users` (id char(36) NOT NULL, email varchar(255) NULL, username varchar(120) NOT NULL, password_hash varchar(255) NOT NULL, google_subject varchar(255) NULL UNIQUE, google_email varchar(255) NULL, is_active tinyint(1) NOT NULL DEFAULT 1, created_at timestamp NOT NULL DEFAULT current_timestamp(), PRIMARY KEY(id), UNIQUE KEY uq_auth_username(username), UNIQUE KEY uq_auth_email(email)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;",
    "CREATE TABLE IF NOT EXISTS `auth_sessions` (id bigint NOT NULL AUTO_INCREMENT, user_id char(36) NOT NULL, token_hash char(64) NOT NULL, expires_at timestamp NOT NULL, last_used_at timestamp NOT NULL DEFAULT current_timestamp(), user_agent varchar(255) NULL, ip_address varchar(64) NULL, PRIMARY KEY(id), UNIQUE KEY uq_auth_token(token_hash), KEY idx_auth_session_user(user_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;",
])
lines.append('SET FOREIGN_KEY_CHECKS=1;')
out.write_text('\n\n'.join(lines) + '\n')
print(f'generated {len(data["tables"])} tables -> {out} ({out.stat().st_size} bytes)')
