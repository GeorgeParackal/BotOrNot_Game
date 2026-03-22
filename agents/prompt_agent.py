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
    user_prompt = f"""
Generate 1 short, creative party-game prompt for a Roblox game called BotOrNot.
Theme: {theme}
The prompt should be fun and make players try to sound like AI.
Return only the prompt text, nothing else.
"""
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=user_prompt,
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