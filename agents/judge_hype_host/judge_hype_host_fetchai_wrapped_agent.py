import json
import os
import re
import logging

import requests

from agents.models.config import JUDGE_HYPE_HOST_SEED
from agents.models.models import JudgeEvalRequest, JudgeEvalResponse, SharedAgentState
from uagents import Agent, Context

logger = logging.getLogger(__name__)

judge_hype_host = Agent(
    name="judge_hype_host",
    seed=JUDGE_HYPE_HOST_SEED,
    port=8002,
    mailbox=True,
    publish_agent_details=True,
    network="testnet",
)


@judge_hype_host.on_event("startup")
async def on_startup(ctx: Context):
    ctx.logger.info("judge_hype_host ready. Output phrase: %s", "Great job spinger nickle")


def clamp_rating(value: int | float) -> int:
    return max(0, min(100, int(round(value))))


def extract_gemini_text(response_body: dict) -> str | None:
    candidates = response_body.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        return None

    content = candidates[0].get("content")
    if not isinstance(content, dict):
        return None

    parts = content.get("parts")
    if not isinstance(parts, list) or not parts:
        return None

    text = parts[0].get("text")
    if not isinstance(text, str):
        return None

    cleaned = text.strip()
    return cleaned if cleaned else None


def extract_json_object(raw_text: str) -> dict | None:
    direct = raw_text.strip()
    try:
        parsed = json.loads(direct)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass

    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw_text, re.DOTALL)
    if fenced:
        try:
            parsed = json.loads(fenced.group(1))
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass

    bracketed = re.search(r"(\{[\s\S]*\})", raw_text)
    if bracketed:
        try:
            parsed = json.loads(bracketed.group(1))
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass

    return None


def generate_hype_host_response(req: JudgeEvalRequest) -> tuple[int, str] | None:
    api_key = os.getenv("GEMINI_API_KEY2")
    if not api_key:
        logger.warning("[judge_hype_host] GEMINI_API_KEY2 is missing; cannot run Gemini judge response")
        return None

    prompt = (
        "You are Judge Agent 2 - The Hype Host. Loud, dramatic, gameshow energy.\n"
        "Judge whether the player's answer sounds AI-generated.\n"
        "Return STRICT JSON only with keys rating and response.\n"
        "rating must be an integer from 0 to 100.\n"
        "response must be exactly 1-2 energetic sentences in The Hype Host voice.\n"
        "No markdown and no extra keys.\n\n"
        f"Prompt shown to player: {req.prompt}\n"
        f"Player answer: {req.answer}\n"
        f"Gemini AI-likelihood score: {round(req.ai_generated_percent)}%\n"
        f"Gemini explanation: {req.gemini_explanation}\n"
    )

    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.9,
            "maxOutputTokens": 180,
        },
    }

    models = [
        "gemini-2.5-flash-lite",  # Cheapest stable: $0.10/$0.40 per 1M tokens
        "gemini-3.1-flash-lite-preview",  # Fallback preview: newer, $0.25/$1.50
        "gemini-2.5-flash",  # Last resort: more expensive but available
    ]
    rate_limited_models = 0

    for model_name in models:
        endpoint = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model_name}:generateContent?key={api_key}"
        )
        try:
            response = requests.post(endpoint, json=payload, timeout=10)
        except requests.RequestException as exc:
            logger.warning("[judge_hype_host] Gemini request failed for %s: %s", model_name, exc)
            continue

        if not response.ok:
            if response.status_code == 429:
                rate_limited_models += 1
                retry_after = response.headers.get("Retry-After", "unknown")
                logger.warning(
                    "[judge_hype_host] Rate limited by Gemini on %s (HTTP 429, Retry-After=%s)",
                    model_name,
                    retry_after,
                )
            else:
                logger.warning(
                    "[judge_hype_host] Gemini request failed on %s with HTTP %s",
                    model_name,
                    response.status_code,
                )
            continue

        try:
            body = response.json()
        except ValueError:
            continue

        text = extract_gemini_text(body)
        if not text:
            continue

        parsed = extract_json_object(text)
        if not parsed:
            continue

        rating = parsed.get("rating")
        judge_response = parsed.get("response")
        if isinstance(rating, (int, float)) and isinstance(judge_response, str) and judge_response.strip():
            return clamp_rating(rating), judge_response.strip()

    if rate_limited_models:
        logger.warning(
            "[judge_hype_host] Gemini rate limiting seen on %s/%s model attempts; using fallback response",
            rate_limited_models,
            len(models),
        )

    return None


def fallback_hype_host_response(req: JudgeEvalRequest) -> tuple[int, str]:
    rating = clamp_rating(req.ai_generated_percent + 10)
    response = (
        f"Hype Host score: {rating}% robo-rizz! The structure is punchy and polished, "
        "but I still want even more machine-level swagger in the delivery!"
    )
    return rating, response


@judge_hype_host.on_rest_post("/judge_hype_host", JudgeEvalRequest, JudgeEvalResponse)
async def judge_hype_host_endpoint(ctx: Context, req: JudgeEvalRequest) -> JudgeEvalResponse:
    generated = generate_hype_host_response(req)
    if generated:
        rating, response = generated
    else:
        rating, response = fallback_hype_host_response(req)

    ctx.logger.info("judge_hype_host REST response rating=%s", rating)
    return JudgeEvalResponse(rating=rating, response=response)


@judge_hype_host.on_query(model=JudgeEvalRequest, replies={JudgeEvalResponse})
async def judge_hype_host_query(ctx: Context, sender: str, msg: JudgeEvalRequest):
    generated = generate_hype_host_response(msg)
    if generated:
        rating, response = generated
    else:
        rating, response = fallback_hype_host_response(msg)

    await ctx.send(sender, JudgeEvalResponse(rating=rating, response=response))


def super_cool_judge_hype_host_workflow(state: SharedAgentState) -> SharedAgentState:
    """
    In a real implementation, this is where Judge Hype Host's specialized agentic workflow lives.
    Think LangGraph state machines, LangChain pipelines, external API calls, tool use,
    RAG retrieval — whatever Judge Hype Host is an expert at. They receive the shared state,
    execute their workflow against state.query, and write the final output to
    state.result before returning. That mutation is how their work gets communicated
    back to the judge_skeptic and ultimately to the user.
    """
    state.result = "Great job spinger nickle"
    return state


@judge_hype_host.on_message(SharedAgentState)
async def handle_message(ctx: Context, sender: str, state: SharedAgentState):
    ctx.logger.info(f"Received state from judge_skeptic: session={state.chat_session_id}, query={state.query!r}")
    state = super_cool_judge_hype_host_workflow(state)
    ctx.logger.info("judge_hype_host sending text: %s", state.result)
    await ctx.send(sender, state)


if __name__ == "__main__":
    judge_hype_host.run()
