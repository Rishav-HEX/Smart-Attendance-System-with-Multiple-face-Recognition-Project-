from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import cv2
from database import create_tables
from registration import router as registration_router
from recognition import recognize_faces
from attendance import mark_attendance
from history import router as history_router
from students import router as students_router
from attendance_history_db import router as attendance_db_router
from dashboard import router as dashboard_router
from fastapi.middleware.cors import CORSMiddleware
from recognition_api import router as recognition_router

app = FastAPI(
    title="Attendance Backend"
)
app.mount(
    "/students-images",
    StaticFiles(directory="students"),
    name="students-images"
) 

app.include_router(recognition_router)
app.include_router(history_router)
app.include_router(students_router)
app.include_router(attendance_db_router)

create_tables()

app.include_router(registration_router)
app.include_router(dashboard_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

@app.get("/")
def home():
    return {
        "message": "Attendance Backend Running"
    }

