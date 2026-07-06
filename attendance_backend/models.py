from pydantic import BaseModel

class StudentRegister(BaseModel):

    student_id: str

    name: str

    roll_no: str

    class_name: str

    section: str