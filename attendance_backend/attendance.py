import pandas as pd
import os

from datetime import datetime
from database import get_connection

ATTENDANCE_FOLDER = "attendance_records"

os.makedirs(
    ATTENDANCE_FOLDER,
    exist_ok=True
)


def mark_attendance(student):

    # GUARD: never attempt to log attendance for an unrecognized face.
    # student["student_id"] is None for "Unknown" entries (see
    # recognition.py's else-branch), and the `attendance` table has
    # student_id as NOT NULL. Without this check, every unmatched face
    # throws sqlite3.IntegrityError, which in turn leaves the connection
    # below unclosed on the error path -> the next request hits
    # "database is locked". This single check fixes both symptoms.
    if not student.get("student_id"):
        return

    today = datetime.now().strftime("%Y-%m-%d")

    csv_path = os.path.join(
        ATTENDANCE_FOLDER,
        f"{today}.csv"
    )

    now = datetime.now()

    record = {
        "Student_ID": student["student_id"],
        "Name": student["name"],
        "Roll_No": student["roll_no"],
        "Date": now.strftime("%Y-%m-%d"),
        "Time": now.strftime("%H:%M:%S")
    }

    # =====================
    # DATABASE ATTENDANCE
    # =====================

    conn = get_connection()

    try:
        cursor = conn.cursor()

        cursor.execute("""
        SELECT *
        FROM attendance
        WHERE student_id=?
        AND attendance_date=?
        """,
        (
            student["student_id"],
            today
        ))

        existing = cursor.fetchone()

        if existing:
            return

        cursor.execute("""
        INSERT INTO attendance
        (
            student_id,
            name,
            roll_no,
            attendance_date,
            attendance_time
        )
        VALUES (?,?,?,?,?)
        """,
        (
            student["student_id"],
            student["name"],
            student["roll_no"],
            now.strftime("%Y-%m-%d"),
            now.strftime("%H:%M:%S")
        ))

        conn.commit()

    finally:
        # Always release the connection, even on early return ("already
        # marked today") or on an unexpected exception. A connection
        # left open here is exactly what causes the next request's
        # write to hit "database is locked".
        conn.close()

    # =====================
    # CSV ATTENDANCE
    # =====================

    if os.path.exists(csv_path):

        df = pd.read_csv(csv_path)

        if student["student_id"] in df["Student_ID"].astype(str).values:
            return

        df = pd.concat(
            [df, pd.DataFrame([record])],
            ignore_index=True
        )

    else:

        df = pd.DataFrame([record])

    df.to_csv(
        csv_path,
        index=False
    )
   