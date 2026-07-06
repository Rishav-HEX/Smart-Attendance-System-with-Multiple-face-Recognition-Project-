from fastapi import APIRouter
from database import get_connection

router = APIRouter()

@router.get("/students")
def get_students():

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
    student_id,
    name,
    roll_no,
    photo_path
    FROM students
    """)

    rows = cursor.fetchall()

    conn.close()

    result = []

    for row in rows:

        result.append({
            "student_id": row[0],
            "name": row[1],
            "roll_no": row[2],
            "photo_path": row[3]
        })

    return result

@router.delete("/student/{student_id}")
def delete_student(student_id: str):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM students WHERE student_id=?",
        (student_id,)
    )

    conn.commit()
    conn.close()

    return {
        "success": True,
        "message": "Student Deleted Successfully"
    }