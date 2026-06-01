from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # fine for testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class SubmissionOut(BaseModel):
    id: int
    person: str
    text: str
    created_at: str


class SubmissionIn(BaseModel):
    person: str
    text: str


VALID_PEOPLE = {"Mary", "Connor"}


@app.get("/")
def root():
    return {"status": "ok"}


@app.get("/submissions/{person}", response_model=list[SubmissionOut])
def get_submissions(person: str):
    if person not in VALID_PEOPLE:
        raise HTTPException(status_code=404, detail="Unknown person")

    with psycopg.connect("dbname=moss user=postgres") as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, person, text, created_at
                FROM submissions
                WHERE person = %s
                ORDER BY created_at DESC
                """,
                (person,),
            )

            rows = cur.fetchall()

    return [
        SubmissionOut(
            id=r[0],
            person=r[1],
            text=r[2],
            created_at=r[3].isoformat() if r[3] else None,
        )
        for r in rows
    ]


@app.post("/submit")
def submit(data: SubmissionIn):
    if data.person not in VALID_PEOPLE:
        raise HTTPException(status_code=400, detail="Unknown person")

    with psycopg.connect("dbname=moss user=postgres") as conn:
        with conn.cursor() as cur:

            cur.execute(
                """
                SELECT 1
                FROM submissions
                WHERE person = %s
                  AND DATE(created_at) = CURRENT_DATE
                LIMIT 1
                """,
                (data.person,),
            )

            if cur.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail="Already submitted today"
                )

            cur.execute(
                """
                INSERT INTO submissions (person, text)
                VALUES (%s, %s)
                RETURNING id
                """,
                (data.person, data.text),
            )

            submission_id = cur.fetchone()[0]

        conn.commit()

    return {
        "status": "saved",
        "id": submission_id,
    }


@app.get("/submitted-today/{person}")
def submitted_today(person: str):
    if person not in VALID_PEOPLE:
        raise HTTPException(status_code=404, detail="Unknown person")

    with psycopg.connect("dbname=moss user=postgres") as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM submissions
                WHERE person = %s
                  AND DATE(created_at) = CURRENT_DATE
                LIMIT 1
                """,
                (person,),
            )

            exists = cur.fetchone() is not None

    return {"submitted": exists}