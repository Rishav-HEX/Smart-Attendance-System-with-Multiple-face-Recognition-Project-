import sqlite3
import os

DB_FOLDER = "database"
DB_PATH = os.path.join(DB_FOLDER, "attendance.db")

os.makedirs(DB_FOLDER, exist_ok=True)


def get_connection():
    # timeout=10: if another connection is mid-write, SQLite will retry
    # for up to 10 seconds instead of raising "database is locked"
    # immediately (the default timeout is 0).
    conn = sqlite3.connect(DB_PATH, timeout=10)

    # WAL (Write-Ahead Logging) lets reads and writes coexist far more
    # gracefully than SQLite's default rollback-journal mode, which is
    # the most common real fix for "database is locked" in apps that
    # take concurrent FastAPI requests (e.g. /recognize-face polling
    # every 700ms while /upload-face runs a write).
    conn.execute("PRAGMA journal_mode=WAL;")

    # busy_timeout as a PRAGMA too, belt-and-suspenders with the
    # connect()-level timeout above — some sqlite3 builds respect one
    # more reliably than the other.
    conn.execute("PRAGMA busy_timeout=10000;")

    return conn


def create_tables():

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS students(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT UNIQUE,
        name TEXT NOT NULL,
        roll_no TEXT NOT NULL,
        photo_path TEXT,
        embedding BLOB
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        name TEXT NOT NULL,
        roll_no TEXT NOT NULL,
        attendance_date TEXT NOT NULL,
        attendance_time TEXT NOT NULL
    )
    """)

    conn.commit()
    conn.close()