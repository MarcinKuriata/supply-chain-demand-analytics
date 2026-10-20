import sqlite3

# 1. Connect to the local SQLite database file
conn = sqlite3.connect("data/supply_chain.db")
cursor = conn.cursor()

# 2. Read and execute the Data Quality SQL script
with open("SQL/00_data_quality_checks.sql", "r", encoding="utf-8") as file:
    sql_script = file.read()

# Split statements by semicolon if executing SELECT queries
queries = [q.strip() for q in sql_script.split(";") if q.strip()]

print("\n--- DATA QUALITY CHECK REPORT ---")
print(f"{'CHECK NAME':<45} | {'FAILED RECORDS':<15}")
print("-" * 65)

for query in queries:
    cursor.execute(query)
    rows = cursor.fetchall()
    for row in rows:
        print(f"{row[0]:<45} | {row[1]:<15}")

conn.close()
print("-" * 65)
print("Data Quality Audit completed.\n")