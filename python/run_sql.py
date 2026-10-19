import sqlite3

# 1. Connect to the local SQLite database file
conn = sqlite3.connect("data/supply_chain.db")

# 2. Read the SQL script file
with open("SQL/03_business_views_kpi.sql", "r", encoding="utf-8") as file:
    sql_script = file.read()

# 3. Execute all SQL statements
print("Executing Star Schema script...")
conn.executescript(sql_script)
conn.close()

print("Done! Star Schema tables created successfully.")