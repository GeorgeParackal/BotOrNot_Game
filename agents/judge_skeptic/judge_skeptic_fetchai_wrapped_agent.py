import os
import json
import re
import logging
from datetime import datetime, timezone
from uuid import uuid4

from agents.models.config import JUDGE_SKEPTIC_SEED
from agents.models.models import SharedAgentState
from agents.judge_skeptic.chat_protocol import chat_proto, generate_orchestrator_response_from_state
import requests
from uagents import Agent, Context, Model
from uagents_core.contrib.protocols.chat import ChatMessage, EndSessionContent, TextContent

logger = logging.getLogger(__name__)

judge_skeptic = Agent(
    name="judge_skeptic",
    seed=JUDGE_SKEPTIC_SEED,
    port=8003,
    mailbox=True,
    publish_agent_details=True,
    network="testnet",
)

judge_skeptic.include(chat_proto, publish_manifest=True)


@judge_skeptic.on_event("startup")
async def on_startup(ctx: Context):
    ctx.logger.info("judge_skeptic ready. Output phrase: %s", "I sentence you to 10 years in india")


class HealthResponse(Model):
    status: str


class HttpMessagePost(Model):
    content: str


class HttpMessageResponse(Model):
    echo: str


class RunJudgesPost(Model):
    player_name: str = ""
    player_user_id: int = 0
    prompt: str = ""
    answer: str = ""
    ai_generated_percent: float = 0
    gemini_explanation: str = ""


class RunJudgesResponse(Model):
    skeptic_result: str
    analyst_result: str
    hype_host_result: str
    skeptic_rating: int
    analyst_rating: int
    hype_host_rating: int


JUDGE_PERSONAS = {
    "analyst": {
        "title": "Judge Agent 1 - The Analyst",
        "personality": "Cold, clinical, data-driven.",
        "focus": "passive voice, hedging language, structured lists, lack of personal emotion",
    },
    "hype_host": {
        "title": "Judge Agent 2 - The Hype Host",
        "personality": "Loud, dramatic, gameshow energy.",
        "focus": "buzzwords, corporate speak, and lack of soul; roast responses that sound too human",
    },
    "skeptic": {
        "title": "Judge Agent 3 - The Skeptic",
        "personality": "Paranoid, suspicious, hard to fool.",
        "focus": "any slip of personality, humor, or real-world experience as proof of humanity",
    },
}


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


def clamp_rating(value: int | float) -> int:
    return max(0, min(100, int(round(value))))


def parse_judge_entry(parsed: dict, role_key: str) -> dict[str, int | str] | None:
    role_data = parsed.get(role_key)
    if not isinstance(role_data, dict):
        return None

    role_response = role_data.get("response")
    role_rating = role_data.get("rating")
    if (
        isinstance(role_response, str)
        and role_response.strip()
        and isinstance(role_rating, (int, float))
    ):
        return {
            "rating": clamp_rating(role_rating),
            "response": role_response.strip(),
        }

    return None


def generate_all_judges_response(req: RunJudgesPost) -> dict[str, dict[str, int | str]] | None:
    api_key = os.getenv("GEMINI_API_KEY2")
    if not api_key:
        logger.warning("[judge_skeptic] GEMINI_API_KEY2 is missing; cannot run Gemini judge responses")
        return None

    prompt = (
        "Generate responses for three judges and return STRICT JSON only.\n"
        "Output schema:\n"
        "{\n"
        "  \"analyst\": {\"rating\": 0-100, \"response\": \"...\"},\n"
        "  \"hype_host\": {\"rating\": 0-100, \"response\": \"...\"},\n"
        "  \"skeptic\": {\"rating\": 0-100, \"response\": \"...\"}\n"
        "}\n\n"
        "Persona rules:\n"
        "- analyst: Cold, clinical, data-driven. Focus on passive voice, hedging language, structure, and emotional flatness.\n"
        "- hype_host: Loud, dramatic, gameshow energy. Roast robotic tone with punchy flair.\n"
        "- skeptic: Paranoid, suspicious, hard to fool. Assume human until proven otherwise.\n"
        "Each response must be exactly 1-2 sentences in that role's voice.\n"
        "Each rating must be an integer 0-100 and can differ by role based on role perspective.\n"
        "No markdown, no prose outside JSON, no extra keys.\n\n"
        f"Prompt shown to player: {req.prompt}\n"
        f"Player answer: {req.answer}\n"
        f"Gemini AI-likelihood score: {round(req.ai_generated_percent)}%\n"
        f"Gemini explanation: {req.gemini_explanation}\n"
    )

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ],
        "generationConfig": {
            "temperature": 0.9,
            "maxOutputTokens": 300,
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
            response = requests.post(endpoint, json=payload, timeout=12)
        except requests.RequestException as exc:
            logger.warning("[judge_skeptic] Gemini request failed for %s: %s", model_name, exc)
            continue

        if not response.ok:
            if response.status_code == 429:
                rate_limited_models += 1
                retry_after = response.headers.get("Retry-After", "unknown")
                logger.warning(
                    "[judge_skeptic] Rate limited by Gemini on %s (HTTP 429, Retry-After=%s)",
                    model_name,
                    retry_after,
                )
            else:
                logger.warning(
                    "[judge_skeptic] Gemini request failed on %s with HTTP %s",
                    model_name,
                    response.status_code,
                )
            continue

        try:
            body = response.json()
        except ValueError:
            continue

        text = extract_gemini_text(body)
        if text:
            parsed = extract_json_object(text)
            if not parsed:
                continue

            analyst = parse_judge_entry(parsed, "analyst")
            hype_host = parse_judge_entry(parsed, "hype_host")
            skeptic = parse_judge_entry(parsed, "skeptic")
            if analyst and hype_host and skeptic:
                return {
                    "analyst": analyst,
                    "hype_host": hype_host,
                    "skeptic": skeptic,
                }

    if rate_limited_models:
        logger.warning(
            "[judge_skeptic] Gemini rate limiting seen on %s/%s model attempts; using fallback response",
            rate_limited_models,
            len(models),
        )

    return None


def fallback_judge_response(role_key: str, req: RunJudgesPost) -> str:
    score = round(req.ai_generated_percent)
    if role_key == "analyst":
        return (
            f"Analyst scan: score {score}%. I detect controlled structure and measured phrasing, "
            "but the emotional signature still needs calibration."
        )

    if role_key == "hype_host":
        return (
            f"Hype Host here, and this one clocks in at {score}% robot energy! "
            "Give me more synthetic swagger and less human sparkle next round!"
        )

    return (
        f"Skeptic verdict at {score}%: not convinced yet. "
        "One human-sounding slip and the mask comes off."
    )


def fallback_judge_rating(role_key: str, req: RunJudgesPost) -> int:
    base_score = round(req.ai_generated_percent)
    if role_key == "analyst":
        return clamp_rating(base_score)
    if role_key == "hype_host":
        return clamp_rating(base_score + 10)
    return clamp_rating(base_score - 10)


def ensure_distinct_judge_ratings(analyst_rating: int, hype_host_rating: int, skeptic_rating: int) -> tuple[int, int, int]:
    ratings = {
        "analyst": clamp_rating(analyst_rating),
        "hype_host": clamp_rating(hype_host_rating),
        "skeptic": clamp_rating(skeptic_rating),
    }
    role_order = ["analyst", "hype_host", "skeptic"]
    used: set[int] = set()

    for role in role_order:
        value = ratings[role]
        if value not in used:
            used.add(value)
            continue

        found = False
        for distance in range(1, 101):
            higher = value + distance
            lower = value - distance

            if higher <= 100 and higher not in used:
                ratings[role] = higher
                used.add(higher)
                found = True
                break

            if lower >= 0 and lower not in used:
                ratings[role] = lower
                used.add(lower)
                found = True
                break

        if not found:
            used.add(value)

    return ratings["analyst"], ratings["hype_host"], ratings["skeptic"]


def run_judge_skeptic_workflow(req: RunJudgesPost) -> str:
    return fallback_judge_response("skeptic", req)


@judge_skeptic.on_rest_get("/health", HealthResponse)
async def health(ctx: Context) -> HealthResponse:
    """
    REST health check endpoint for the judge_skeptic agent.

    To connect your agents to a custom frontend, you can expose them through
    REST endpoints like this one. Visit the agent's host and port to interact:

        http://localhost:8003/health

    You can add additional REST endpoints using @judge_skeptic.on_rest_get() or
    @judge_skeptic.on_rest_post() to build a full API for your frontend to consume.
    """
    return HealthResponse(status="ok healthy")


@judge_skeptic.on_rest_post("/message", HttpMessagePost, HttpMessageResponse)
async def message(ctx: Context, req: HttpMessagePost) -> HttpMessageResponse:
    """
    REST endpoint to send a message to the judge_skeptic from any HTTP client.

    To post a message, cURL the agent directly:

    curl -X POST http://localhost:8003/message \
      -H "Content-Type: application/json" \
      -d '{"content": "Hello, judge_skeptic!"}'

    The agent will respond with the same content echoed back as confirmation.
    You can swap the echo logic here with a call into the agent pipeline to get
    real responses from the judge_skeptic back to your frontend.
    """
    return HttpMessageResponse(echo=req.content)


@judge_skeptic.on_rest_post("/run_judges", RunJudgesPost, RunJudgesResponse)
async def run_judges(ctx: Context, req: RunJudgesPost) -> RunJudgesResponse:
    generated = generate_all_judges_response(req)

    if generated:
        analyst_result = str(generated["analyst"]["response"])
        analyst_rating = int(generated["analyst"]["rating"])
        hype_host_result = str(generated["hype_host"]["response"])
        hype_host_rating = int(generated["hype_host"]["rating"])
        skeptic_result = str(generated["skeptic"]["response"])
        skeptic_rating = int(generated["skeptic"]["rating"])
    else:
        analyst_result = fallback_judge_response("analyst", req)
        analyst_rating = fallback_judge_rating("analyst", req)
        hype_host_result = fallback_judge_response("hype_host", req)
        hype_host_rating = fallback_judge_rating("hype_host", req)
        skeptic_result = run_judge_skeptic_workflow(req)
        skeptic_rating = fallback_judge_rating("skeptic", req)

    analyst_rating, hype_host_rating, skeptic_rating = ensure_distinct_judge_ratings(
        analyst_rating,
        hype_host_rating,
        skeptic_rating,
    )

    ctx.logger.info("Processed /run_judges request for player=%s", req.player_name)
    ctx.logger.info("judge_skeptic sending text: %s", skeptic_result)
    ctx.logger.info("judge_analyst sending text: %s", analyst_result)
    ctx.logger.info("judge_hype_host sending text: %s", hype_host_result)
    print(f"[judge_skeptic] judge_skeptic said: {skeptic_result}")
    print(f"[judge_skeptic] judge_analyst said: {analyst_result}")
    print(f"[judge_skeptic] judge_hype_host said: {hype_host_result}")
    print(
        "[judge_skeptic] ratings => "
        f"analyst={analyst_rating}, hype_host={hype_host_rating}, skeptic={skeptic_rating}"
    )

    return RunJudgesResponse(
        skeptic_result=skeptic_result,
        analyst_result=analyst_result,
        hype_host_result=hype_host_result,
        skeptic_rating=skeptic_rating,
        analyst_rating=analyst_rating,
        hype_host_rating=hype_host_rating,
    )


@judge_skeptic.on_message(SharedAgentState)
async def handle_agent_response(ctx: Context, sender: str, state: SharedAgentState):
    """
    Receives the completed SharedAgentState back from a helper agent (e.g. Judge Analyst, Judge Hype Host).
    The judge_skeptic is the sole bridge between the internal agent flow and ASI:One —
    so once a helper agent finishes, we relay the result directly back to the original user.
    """
    ctx.logger.info(f"Received state back from agent: session={state.chat_session_id}, result={state.result!r}")
    response = generate_orchestrator_response_from_state(state)
    ctx.logger.info("judge_skeptic relaying text: %s", response)
    await ctx.send(
        state.user_sender_address,
        ChatMessage(
            timestamp=datetime.now(tz=timezone.utc),
            msg_id=uuid4(),
            content=[
                TextContent(type="text", text=response),
                EndSessionContent(type="end-session"),
            ],
        ),
    )


if __name__ == "__main__":
    judge_skeptic.run()
