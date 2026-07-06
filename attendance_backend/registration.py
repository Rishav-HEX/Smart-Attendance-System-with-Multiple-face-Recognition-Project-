from fastapi import APIRouter, UploadFile, File
from models import StudentRegister
from database import get_connection

import cv2
import os
import pickle
import numpy as np

from face_engine import get_face_embedding_from_image

router = APIRouter()

STUDENT_FOLDER = "students"
os.makedirs(STUDENT_FOLDER, exist_ok=True)


@router.post("/register-student")
def register_student(student: StudentRegister):

    conn = get_connection()

    try:
        cursor = conn.cursor()

        cursor.execute("""
    INSERT INTO students
    (
        student_id,
        name,
        roll_no,
        class_name,
        section
    )
    VALUES (?,?,?,?,?)
""",
(
    student.student_id,
    student.name,
    student.roll_no,
    student.class_name,
    student.section
))

        conn.commit()

        return {
            "success": True,
            "message": "Student Registered Successfully"
        }

    except Exception as e:

        return {
            "success": False,
            "error": str(e)
        }

    finally:
        conn.close()


@router.post("/upload-face/{student_id}")
async def upload_face(
    student_id: str,
    file: UploadFile = File(...)
):

    image_bytes = await file.read()

    np_array = np.frombuffer(
        image_bytes,
        np.uint8
    )

    image = cv2.imdecode(
        np_array,
        cv2.IMREAD_COLOR
    )

    if image is None:

        return {
            "success": False,
            "message": "Invalid Image"
        }

    image_path = os.path.join(
        STUDENT_FOLDER,
        f"{student_id}.jpg"
    )

    cv2.imwrite(
        image_path,
        image
    )

    embedding = get_face_embedding_from_image(
        image
    )

    if embedding is None:

        return {
            "success": False,
            "message": "No Face Detected"
        }

    conn = get_connection()

    try:
        cursor = conn.cursor()

        cursor.execute("""
        UPDATE students
        SET photo_path=?,
            embedding=?
        WHERE student_id=?
        """,
        (
            image_path,
            pickle.dumps(embedding),
            student_id
        ))

        conn.commit()

    finally:
        # Always release the connection, even if the UPDATE raises.
        # A connection left open after an exception is the most common
        # way a later request hits "database is locked" on SQLite,
        # since SQLite only allows one writer at a time.
        conn.close()

    # CRITICAL FIX: reload the in-memory recognition cache immediately
    # after writing a new embedding to the database. Without this, the
    # newly registered student is invisible to /recognize-face until
    # the FastAPI process is restarted, because recognition.py only
    # loads STUDENTS_CACHE once at import time.
    from recognition import refresh_students_cache
    refresh_students_cache()

    return {
        "success": True,
        "photo_saved": image_path
    }


@router.post("/recognize-face")
async def recognize_face(
    file: UploadFile = File(...)
):

    image_bytes = await file.read()

    np_array = np.frombuffer(
        image_bytes,
        np.uint8
    )

    image = cv2.imdecode(
        np_array,
        cv2.IMREAD_COLOR
    )

    if image is None:

        return {
            "success": False,
            "message": "Invalid Image"
        }

    from recognition import recognize_faces

    results = recognize_faces(image)

    if len(results) == 0:

        return {
            "success": False,
            "message": "No Face Detected",
            "recognized": []
        }

    # FIX: mark attendance for every recognized face in this frame,
    # not just the first one.
    from attendance import mark_attendance

    for student in results:
        if student.get("student_id") is not None:
            mark_attendance(student)

    # FIX: return the FULL list under "recognized", matching what the
    # Flutter app actually reads (result["recognized"]). The previous
    # version returned only `results[0]` under a "student" key, which
    # both dropped every face after the first AND didn't match the
    # key name the frontend expects.
    return {
        "success": True,
        "recognized": results
    }