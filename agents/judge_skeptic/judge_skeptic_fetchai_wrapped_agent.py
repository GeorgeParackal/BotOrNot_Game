from datetime import datetime, timezone
from uuid import uuid4

from agents.models.config import JUDGE_SKEPTIC_SEED
from agents.models.models import SharedAgentState
from agents.judge_skeptic.chat_protocol import chat_proto, generate_orchestrator_response_from_state
from uagents import Agent, Context, Model
from uagents_core.contrib.protocols.chat import ChatMessage, EndSessionContent, TextContent

judge_skeptic = Agent(
    name="judge_skeptic",
    seed=JUDGE_SKEPTIC_SEED,
    port=8003,
    mailbox=True,
    publish_agent_details=True,
    network="testnet",
)

judge_skeptic.include(chat_proto, publish_manifest=True)


class HealthResponse(Model):
    status: str


class HttpMessagePost(Model):
    content: str


class HttpMessageResponse(Model):
    echo: str


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


@judge_skeptic.on_message(SharedAgentState)
async def handle_agent_response(ctx: Context, sender: str, state: SharedAgentState):
    """
    Receives the completed SharedAgentState back from a helper agent (e.g. Judge Analyst, Judge Hype Host).
    The judge_skeptic is the sole bridge between the internal agent flow and ASI:One —
    so once a helper agent finishes, we relay the result directly back to the original user.
    """
    ctx.logger.info(f"Received state back from agent: session={state.chat_session_id}, result={state.result!r}")
    response = generate_orchestrator_response_from_state(state)
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
