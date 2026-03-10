import os
from pathlib import Path

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from openai import AsyncOpenAI

from app.pipeline import generate_plan

load_dotenv()

app = FastAPI(title="Lesson Plan Generator")

_client = AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])


@app.post("/plans/{lesson_id}")
async def create_plan(lesson_id: str):
    try:
        plan = await generate_plan(
            lesson_id=lesson_id,
            output_dir=Path(os.getenv("OUTPUT_DIR", "output")),
            openai_client=_client,
            tts_voice=os.getenv("TTS_VOICE", "alloy"),
        )
        return plan
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=int(os.getenv("PORT", "8200")), reload=True)
