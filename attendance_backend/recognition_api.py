from fastapi import APIRouter
from fastapi import UploadFile, File

import cv2
import numpy as np

from recognition import recognize_from_image
from attendance import mark_attendance

router = APIRouter()


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
    print(image.shape)
    if image is None:

        return {
            "success": False,
            "message": "Invalid Image"
        }

    results = recognize_from_image(
        image
    )

    for student in results:

        mark_attendance(
            student
        )

    return {
        "success": True,
        "recognized": results
    }