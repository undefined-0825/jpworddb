import sqlite3
conn = sqlite3.connect('data/jpword.db')
tables = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print('Tables:', tables)
for t in tables:
    name = t[0]
    cols = conn.execute('PRAGMA table_info(' + name + ')').fetchall()
    print(name + ': ' + str([c[1] for c in cols]))
    cnt = conn.execute('SELECT COUNT(*) FROM ' + name).fetchone()
    print('  count: ' + str(cnt[0]))
conn.close()
