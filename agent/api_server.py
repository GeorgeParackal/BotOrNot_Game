import json
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from uagents import Model
from uagents.query import query

PROMPT_AGENT_ADDRESS = "agent1qds69y9hpu4h970m66tnn9sruj8u5gew3e05c2j9fvr3l0cguerjjv8kjst"

app = FastAPI()

class PromptRequest(Model):
    theme: str = "general"

@app.get("/")
async def root():
    return {"status": "ok", "message": "API server is running"}

async def ask_prompt_agent(theme: str) -> str:
    req = PromptRequest(theme=theme)
    response = await query(
        destination=PROMPT_AGENT_ADDRESS,
        message=req,
        timeout=15,
    )

    if hasattr(response, "decode_payload"):
        data = json.loads(response.decode_payload())
        return data["prompt"]

    raise RuntimeError(f"Agent query failed: {response}")

@app.get("/prompt")
async def get_prompt(theme: str = "general"):
    try:
        prompt = await ask_prompt_agent(theme)
        return {"prompt": prompt}
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )