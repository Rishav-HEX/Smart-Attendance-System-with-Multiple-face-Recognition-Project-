import cv2
import numpy as np
from insightface.app import FaceAnalysis

# Load InsightFace Model
app = FaceAnalysis(
    name="buffalo_l",
    providers=["CPUExecutionProvider"]
)

app.prepare(ctx_id=0)


def get_face_embedding(image_path):
    """
    Generate embedding from image file path
    """

    image = cv2.imread(image_path)

    if image is None:
        return None

    faces = app.get(image)

    if len(faces) == 0:
        return None

    embedding = faces[0].embedding

    return np.array(
        embedding,
        dtype=np.float32
    )


def get_face_embedding_from_image(image):
    """
    Generate embedding directly from OpenCV image
    """

    if image is None:
        return None

    faces = app.get(image)

    if len(faces) == 0:
        return None

    embedding = faces[0].embedding

    return np.array(
        embedding,
        dtype=np.float32
    )