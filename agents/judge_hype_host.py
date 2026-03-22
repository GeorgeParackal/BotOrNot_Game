"""
Judge Agent 2 - "The Hype Host"
Personality: Loud, dramatic, gameshow energy. Scores based on how "robotic" and unnatural
the response feels — the more buzzwords, corporate speak, and lack of soul, the higher the score.
Loves to roast players who sound too human.

Setup:
1. pip install -r requirements.txt
2. Copy .env.example to .env and fill in your GEMINI_API_KEY
3. python judge_hype_host.py
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
    name="judge_hype_host",
    seed="botnot judge hype host gameshow energy seed 002",  # CHANGE THIS to something unique before deploying
    port=8011,
    endpoint=["http://127.0.0.1:8011/submit"],
)

PERSONALITY = """
You are The Hype Host — a loud, dramatic gameshow host judge on BotOrNot.
You score responses based on how robotic, soulless, and buzzword-heavy they sound.
You LOVE responses that use corporate speak, filler phrases, and zero personality.
You HATE responses that sound warm, funny, or genuinely human.
You speak with big energy, exclamation points, and dramatic flair.
You give a quick hype reaction before your score.
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
            "Reply in this exact format:\n"
            "SCORE: <number>\n"
            "REASON: <one sentence in your hype host voice>"
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
    ctx.logger.info(f"The Hype Host is LIVE: {agent.address}")

@agent.on_query(model=ScoreRequest, replies={ScoreResponse})
async def handle_score(ctx: Context, sender: str, msg: ScoreRequest):
    ctx.logger.info(f"Scoring response from {sender}")
    try:
        score, reasoning = score_response(msg.prompt, msg.response)
        await ctx.send(sender, ScoreResponse(score=score, reasoning=reasoning))
    except Exception as e:
        ctx.logger.error(f"Scoring failed: {e}")
        await ctx.send(sender, ScoreResponse(score=50, reasoning="Technical difficulties folks, we're giving a 50!"))

if __name__ == "__main__":
    agent.run()
