from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import date
import psycopg

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], ## probably fine for testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class SubmissionOut(BaseModel):
    id: int
    person: str
    text: str
    created_at: str ## note for future connor --
                    ## postgres returns a datetime, converting with
                    ## .isoformat is fine for now, bugs may arise if
                    ## db changes!

class SubmissionIn(BaseModel):
    person: str
    text: str


@app.get("/")
def root():
    return {"status": "ok"}


@app.get("/submissions", response_model=list[SubmissionOut])
def get_submissions():
    with psycopg.connect("dbname=moss user=postgres") as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, person, text, created_at
                FROM submissions
                ORDER BY created_at DESC
            """)
            rows = cur.fetchall()
    return [
        SubmissionOut(
            id=r[0],
            person=r[1],
            text=r[2],
            created_at=r[3].isoformat() if r[3] else None
        )
        for r in rows
    ]


@app.post("/submit")
def submit(data: SubmissionIn):
    with psycopg.connect(
        "dbname=moss user=postgres"
    ) as conn:
        with conn.cursor() as cur:
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