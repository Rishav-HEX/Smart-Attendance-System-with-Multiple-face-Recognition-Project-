import pickle
import numpy as np

from database import get_connection
from face_engine import app


def load_students():

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT student_id,name,roll_no,embedding
    FROM students
    WHERE embedding IS NOT NULL
    """)

    rows = cursor.fetchall()

    conn.close()

    students = []

    for row in rows:

        students.append({
            "student_id": row[0],
            "name": row[1],
            "roll_no": row[2],
            "embedding": pickle.loads(row[3])
        })

    return students


# Load once at startup...
STUDENTS_CACHE = load_students()


def refresh_students_cache():
    """
    Re-reads all student embeddings from the database into memory.
    MUST be called after every successful registration/upload-face,
    otherwise newly registered students are invisible to recognition
    until the server process restarts.
    """
    global STUDENTS_CACHE
    STUDENTS_CACHE = load_students()
    print(f"[CACHE] Reloaded {len(STUDENTS_CACHE)} student embeddings")
    return STUDENTS_CACHE


def cosine_similarity(a, b):

    return np.dot(a, b) / (
        np.linalg.norm(a) *
        np.linalg.norm(b)
    )


def _run_recognition(frame):
    """
    Shared logic: detect every face in `frame`, match each against
    STUDENTS_CACHE, return one result entry per detected face
    (whether matched or not, so the UI can show "Unknown" boxes too).
    """

    students = STUDENTS_CACHE

    faces = app.get(frame)

    results = []

    for face in faces:

        current_embedding = face.embedding

        best_score = 0
        best_student = None

        for student in students:

            score = cosine_similarity(
                current_embedding,
                student["embedding"]
            )

            if score > best_score:
                best_score = score
                best_student = student

        bbox = face.bbox.astype(int)

        if best_student is not None and best_score > 0.60:

            results.append({
                "student_id": best_student["student_id"],
                "name": best_student["name"],
                "roll_no": best_student["roll_no"],
                "score": float(best_score),
                "x1": int(bbox[0]),
                "y1": int(bbox[1]),
                "x2": int(bbox[2]),
                "y2": int(bbox[3]),
            })

        else:
            # Still report the box so the Flutter UI can draw an
            # "Unknown" bracket on every detected face, not just
            # matched ones. Drop this else-branch if you only ever
            # want recognized faces returned.
            results.append({
                "student_id": None,
                "name": "Unknown",
                "roll_no": None,
                "score": float(best_score),
                "x1": int(bbox[0]),
                "y1": int(bbox[1]),
                "x2": int(bbox[2]),
                "y2": int(bbox[3]),
            })

    return results


def recognize_faces(frame):
    return _run_recognition(frame)


def recognize_from_image(image):
    return _run_recognition(image)