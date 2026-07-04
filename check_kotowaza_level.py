import sqlite3

db_path = r"c:\dev\jpworddb\src\quicktap\assets\jpword.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Level が設定されているレコード数を確認
cursor.execute("SELECT COUNT(*) as cnt FROM kotowaza WHERE level IS NOT NULL")
result = cursor.fetchone()
print(f"Records with level set: {result[0]}")

# Level の分布を確認
cursor.execute("SELECT level, COUNT(*) as cnt FROM kotowaza WHERE level IS NOT NULL GROUP BY level ORDER BY level")
results = cursor.fetchall()
print("\nLevel distribution:")
for level, cnt in results:
    print(f"  Level {level}: {cnt} records")

# NULLレベルを確認
cursor.execute("SELECT COUNT(*) as cnt FROM kotowaza WHERE level IS NULL")
result = cursor.fetchone()
print(f"\nRecords with NULL level: {result[0]}")

# Sampling a few records
cursor.execute("SELECT id, word, level FROM kotowaza LIMIT 10")
samples = cursor.fetchall()
print("\nFirst 10 records:")
for sample in samples:
    print(sample)

conn.close()
