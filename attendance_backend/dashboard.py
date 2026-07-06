from fastapi import APIRouter
from database import get_connection

router = APIRouter()


@router.get("/dashboard")
def dashboard():

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT COUNT(*) FROM students"
    )
    total_students = cursor.fetchone()[0]

    cursor.execute(
        "SELECT COUNT(*) FROM attendance"
    )
    total_attendance = cursor.fetchone()[0]

    conn.close()

    return {
        "total_students": total_students,
        "total_attendance": total_attendance
    }