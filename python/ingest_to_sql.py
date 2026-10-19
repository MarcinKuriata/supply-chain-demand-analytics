import os
import sqlite3
import pandas as pd


def load_raw_data_to_sqlite():
    # Define file paths
    raw_data_path = os.path.join(
        "..", "data", "raw", "DataCoSupplyChainDataset.csv"
    )
    db_path = os.path.join("..", "data", "supply_chain.db")

    if not os.path.exists(raw_data_path):
        # Fallback if executed from project root
        raw_data_path = os.path.join(
            "data", "raw", "DataCoSupplyChainDataset.csv"
        )
        db_path = os.path.join("data", "supply_chain.db")

    print(f"Reading raw data from: {raw_data_path}")

    # Load dataset with fallback encoding commonly needed for DataCo dataset
    try:
        df = pd.read_csv(raw_data_path, encoding="utf-8")
    except UnicodeDecodeError:
        df = pd.read_csv(raw_data_path, encoding="ISO-8859-1")

    print(f"Raw dataset loaded successfully. Shape: {df.shape}")

    # Standardize column names to snake_case for clean SQL consumption
    df.columns = (
        df.columns.str.strip()
        .str.lower()
        .str.replace(" ", "_")
        .str.replace("(", "", regex=False)
        .str.replace(")", "", regex=False)
    )

    # Establish SQLite connection
    conn = sqlite3.connect(db_path)

    # Write raw table into SQLite
    table_name = "raw_supply_chain_data"
    print(f"Writing data into SQL table: '{table_name}'...")
    df.to_sql(table_name, conn, if_exists="replace", index=False)

    # Validate row count
    cursor = conn.cursor()
    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    row_count = cursor.fetchone()[0]

    print(
        f"Database ingestion complete. Total rows in '{table_name}': {row_count}"
    )

    conn.close()


if __name__ == "__main__":
    load_raw_data_to_sqlite()