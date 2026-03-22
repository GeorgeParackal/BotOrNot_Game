"""
Judge Agent 1 - "The Analyst"
Personality: Cold, clinical, data-driven. Scores based on technical AI writing patterns.
Looks for: passive voice, hedging language, structured lists, lack of personal emotion.

Setup:
1. pip install -r requirements.txt
2. Copy .env.example to .env and fill in your GEMINI_API_KEY
3. python judge_analyst.py
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
    name="judge_analyst",
    seed="botnot judge analyst cold clinical data seed 001",  # CHANGE THIS to something unique before deploying
    port=8010,
    endpoint=["http://127.0.0.1:8010/submit"],
)

PERSONALITY = """
You are The Analyst — a cold, clinical AI judge in a game show called BotOrNot.
You evaluate responses purely on technical writing patterns associated with AI output.
You look for: passive voice, hedging phrases ("it is worth noting", "one might consider"),
structured reasoning, lack of personal anecdotes, formal vocabulary, and emotional detachment.
You do NOT care about creativity or fun. Only technical AI-likeness matters to you.
You speak in short, precise sentences. No warmth.
"""

class ScoreRequest(Model):
    prompt: str
    response: str

class ScoreResponse(Model):
    score: int        # 0-100 AI likeness
    reasoning: str    # one sentence explanation

def score_response(prompt: str, response: str) -> tuple[int, str]:
    result = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=(
            f"{PERSONALITY}\n\n"
            f"Game prompt: \"{prompt}\"\n"
            f"Player response: \"{response}\"\n\n"
            "Rate how much this response sounds like AI-generated text, from 0 to 100.\n"
            "0 = clearly human, 100 = indistinguishable from AI.\n"
            "Reply in this exact format:\n"
            "SCORE: <number>\n"
            "REASON: <one sentence>"
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
    ctx.logger.info(f"The Analyst is online: {agent.address}")

@agent.on_query(model=ScoreRequest, replies={ScoreResponse})
async def handle_score(ctx: Context, sender: str, msg: ScoreRequest):
    ctx.logger.info(f"Scoring response from {sender}")
    try:
        score, reasoning = score_response(msg.prompt, msg.response)
        await ctx.send(sender, ScoreResponse(score=score, reasoning=reasoning))
    except Exception as e:
        ctx.logger.error(f"Scoring failed: {e}")
        await ctx.send(sender, ScoreResponse(score=50, reasoning="Scoring error — defaulting to 50."))

if __name__ == "__main__":
    agent.run()
