import psycopg

conn = psycopg.connect(
    "dbname=moss user=postgres"
)

cur = conn.cursor()
cur.execute(
    "SELECT version();"
)
print(cur.fetchone())

conn.close()