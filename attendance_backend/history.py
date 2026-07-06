import os
import pandas as pd
from fastapi import APIRouter

router = APIRouter()

ATTENDANCE_FOLDER = "attendance_records"


@router.get("/attendance-history")
def attendance_history():

    records = []

    if not os.path.exists(ATTENDANCE_FOLDER):
        return []

    for file in os.listdir(ATTENDANCE_FOLDER):

        if file.endswith(".csv"):

            path = os.path.join(
                ATTENDANCE_FOLDER,
                file
            )

            df = pd.read_csv(path)

            records.extend(
                df.to_dict("records")
            )

    return records