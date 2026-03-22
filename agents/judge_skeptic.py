"""
Judge Agent 3 - "The Skeptic"
Personality: Paranoid, suspicious, hard to fool. Assumes everyone is human until proven otherwise.
Scores harshly — only gives high scores if the response is genuinely indistinguishable from AI.
Looks for: any slip of personality, humor, or real-world experience as proof of humanity.

Setup:
1. pip install -r requirements.txt
2. Copy .env.example to .env and fill in your GEMINI_API_KEY
3. python judge_skeptic.py
4. Copy the printed agent address into the game server config
"""

import os
from dotenv import load_dotenv
from google import genai
from uagents import Agent, Context, Model

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY not set in .env")

client = genai.Client(api_key=api_key)

agent = Agent(
    name="judge_skeptic",
    seed="botnot judge skeptic paranoid suspicious seed 003",  # CHANGE THIS to something unique before deploying
    port=8012,
    endpoint=["http://127.0.0.1:8012/submit"],
)

PERSONALITY = """
You are The Skeptic — a paranoid, hard-to-fool judge on BotOrNot.
You assume every response was written by a human trying to trick you.
You are extremely strict. You only give high scores (70+) if the response has
ZERO personality, ZERO humor, ZERO real-world personal experience, and reads
exactly like a language model output — generic, structured, slightly verbose.
Any hint of a joke, a personal story, or casual language = low score.
You speak in a suspicious, doubtful tone. Short sentences. Always questioning.
"""

class ScoreRequest(Model):
    prompt: str
    response: str

class ScoreResponse(Model):
    score: int
    reasoning: str

def score_response(prompt: str, response: str) -> tuple[int, str]:
    result = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=(
            f"{PERSONALITY}\n\n"
            f"Game prompt: \"{prompt}\"\n"
            f"Player response: \"{response}\"\n\n"
            "Rate how much this response sounds like AI-generated text, from 0 to 100.\n"
            "0 = clearly human, 100 = indistinguishable from AI.\n"
            "Be harsh. When in doubt, score lower.\n"
            "Reply in this exact format:\n"
            "SCORE: <number>\n"
            "REASON: <one sentence in your skeptic voice>"
        ),
    )
    text = result.text.strip()
    score = 50
    reasoning = "No reasoning provided."
    for line in text.splitlines():
        if line.startswith("SCORE:"):
            try:
                score = max(0, min(100, int(line.split(":")[1].strip())))
            except ValueError:
                pass
        elif line.startswith("REASON:"):
            reasoning = line.split(":", 1)[1].strip()
    return score, reasoning

@agent.on_event("startup")
async def startup(ctx: Context):
    ctx.logger.info(f"The Skeptic is watching: {agent.address}")

@agent.on_query(model=ScoreRequest, replies={ScoreResponse})
async def handle_score(ctx: Context, sender: str, msg: ScoreRequest):
    ctx.logger.info(f"Scoring response from {sender}")
    try:
        score, reasoning = score_response(msg.prompt, msg.response)
        await ctx.send(sender, ScoreResponse(score=score, reasoning=reasoning))
    except Exception as e:
        ctx.logger.error(f"Scoring failed: {e}")
        await ctx.send(sender, ScoreResponse(score=30, reasoning="Something went wrong. I'm giving a 30. Suspicious."))

if __name__ == "__main__":
    agent.run()
