from fastapi import APIRouter
from database import get_connection
from fastapi.responses import FileResponse
import os

router = APIRouter()


from typing import Optional

@router.get("/attendance-db")
def attendance_db(date: Optional[str] = None):

    conn = get_connection()
    cursor = conn.cursor()

    if date:

        cursor.execute("""
        SELECT
        student_id,
        name,
        roll_no,
        attendance_date,
        attendance_time
        FROM attendance
        WHERE attendance_date=?
        ORDER BY attendance_time DESC
        """, (date,))

    else:

        cursor.execute("""
        SELECT
        student_id,
        name,
        roll_no,
        attendance_date,
        attendance_time
        FROM attendance
        ORDER BY attendance_date DESC,
                 attendance_time DESC
        """)

    rows = cursor.fetchall()

    conn.close()

    data = []

    for row in rows:

        data.append({
            "student_id": row[0],
            "name": row[1],
            "roll_no": row[2],
            "date": row[3],
            "time": row[4]
        })

    return data

@router.get("/download-attendance/{date}")
def download_attendance(date: str):

    file_path = f"attendance_records/{date}.csv"

    if not os.path.exists(file_path):
        return {
            "success": False,
            "message": "Attendance file not found"
        }

    return FileResponse(
        path=file_path,
        filename=f"Attendance_{date}.csv",
        media_type="text/csv"
    )

@router.get("/attendance/{date}")
def attendance_by_date(date: str):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
    student_id,
    name,
    roll_no,
    attendance_date,
    attendance_time
    FROM attendance
    WHERE attendance_date=?
    """, (date,))

    rows = cursor.fetchall()

    conn.close()

    result = []

    for row in rows:

        result.append({
            "student_id": row[0],
            "name": row[1],
            "roll_no": row[2],
            "date": row[3],
            "time": row[4]
        })

    return result
@router.get("/student-profile/{student_id}")
def student_profile(student_id: str):

    conn = get_connection()
    cursor = conn.cursor()

    # Student Details
    cursor.execute("""
    SELECT
    student_id,
    name,
    roll_no,
    class_name,
    section,
    photo_path
    FROM students
    WHERE student_id=?
    """, (student_id,))

    student = cursor.fetchone()

    if not student:
        conn.close()
        return {
            "success": False,
            "message": "Student Not Found"
        }

    # Present Days
    cursor.execute("""
    SELECT COUNT(*)
    FROM attendance
    WHERE student_id=?
    """, (student_id,))

    present_days = cursor.fetchone()[0]

    # Last Attendance
    cursor.execute("""
    SELECT
    attendance_date,
    attendance_time
    FROM attendance
    WHERE student_id=?
    ORDER BY attendance_date DESC,
             attendance_time DESC
    LIMIT 1
    """, (student_id,))

    last_attendance = cursor.fetchone()

    # Total Working Days
    cursor.execute("""
    SELECT COUNT(DISTINCT attendance_date)
    FROM attendance
    """)

    total_working_days = cursor.fetchone()[0]

    attendance_percentage = (
        round(
            (present_days / total_working_days) * 100,
            2
        )
        if total_working_days > 0
        else 0
    )

    # CLOSE DATABASE HERE
    conn.close()

    return {
        "success": True,

        "student_id": student[0],
        "name": student[1],
        "roll_no": student[2],
        "class_name": student[3],
        "section": student[4],
        "photo_path": student[5],

        "present_days": present_days,
        "total_working_days": total_working_days,
        "attendance_percentage": attendance_percentage,

        "last_attendance":
            f"{last_attendance[0]} {last_attendance[1]}"
            if last_attendance else "N/A"
    }