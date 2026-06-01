from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], ## probably fine for testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Submission(BaseModel):
    person: str
    text: str


@app.get("/")
def root():
    return {"status": "ok"}


@app.post("/submit")
def submit(data: Submission):
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