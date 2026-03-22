import os
from dotenv import load_dotenv
from google import genai
from uagents import Agent, Context, Model

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY not found in .env")

client = genai.Client(api_key=api_key)

agent = Agent(
    name="prompt_generator_agent",
    seed="bot or not prompt generator seed phrase 12345",
    port=8001,
    endpoint=["http://127.0.0.1:8001/submit"],
)

class PromptRequest(Model):
    theme: str = "general"

class PromptResponse(Model):
    prompt: str

def generate_prompt(theme: str) -> str:
    user_prompt = """
Generate exactly 1 party-game writing prompt for Roblox BotOrNot.
Requirements:
- Return only the prompt text.
- Length must be 2 to 3 complete sentences.
- Make it very random and unpredictable.
- Do not anchor on one topic category; mix surprising details.
- Avoid repeating common school-style themes and avoid reusing wording patterns.
- Make it answerable by anyone.
- Include at least one direct question ending with a question mark.
"""
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=user_prompt,
        config={
            "temperature": 1.4,
            "top_p": 0.95,
            "max_output_tokens": 90,
        },
    )
    return response.text.strip()

@agent.on_event("startup")
async def startup(ctx: Context):
    ctx.logger.info(f"Prompt agent started: {agent.address}")

@agent.on_query(model=PromptRequest, replies={PromptResponse})
async def handle_prompt_request(ctx: Context, sender: str, msg: PromptRequest):
    ctx.logger.info(f"Received query from {sender} with theme: {msg.theme}")
    try:
        generated_prompt = generate_prompt(msg.theme)
        await ctx.send(sender, PromptResponse(prompt=generated_prompt))
        ctx.logger.info(f"Sent prompt: {generated_prompt}")
    except Exception as e:
        ctx.logger.error(f"Prompt generation failed: {e}")
        await ctx.send(sender, PromptResponse(prompt="Describe why robots deserve weekends."))

if __name__ == "__main__":
    agent.run()