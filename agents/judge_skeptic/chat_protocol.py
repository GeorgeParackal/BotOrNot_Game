from datetime import datetime, timezone
from uuid import uuid4

from uagents import Context, Protocol
from agents.models.models import SharedAgentState
from agents.services.state_service import state_service
from uagents_core.contrib.protocols.chat import (
    ChatAcknowledgement,
    ChatMessage,
    EndSessionContent,
    TextContent,
    chat_protocol_spec,
)

chat_proto = Protocol(spec=chat_protocol_spec)


@chat_proto.on_message(ChatMessage)
async def handle_message(ctx: Context, sender: str, msg: ChatMessage):
    await ctx.send(
        sender,
        ChatAcknowledgement(timestamp=datetime.now(), acknowledged_msg_id=msg.msg_id),
    )

    text = " ".join(
        item.text for item in msg.content if isinstance(item, TextContent)
    )
    ctx.logger.info(f"Received: {text}")

    chat_session_id = str(ctx.session)
    state = state_service.get_state(chat_session_id)

    if state is None:
        state = SharedAgentState(
            chat_session_id=chat_session_id,
            query=text,
            user_sender_address=sender,
        )
        state_service.set_state(chat_session_id, state)
    else:
        state.query = text

    response = None

    if "judge_analyst" in text.lower() or "judge_hype_host" in text.lower() or "judge_skeptic" in text.lower():
        response = (
            "Judge routing is running in local single-call mode now. "
            "Use the /run_judges REST endpoint to get analyst, hype_host, and skeptic outputs together."
        )
    else:
        response = (
            "Mention judge_analyst, judge_hype_host, or judge_skeptic to receive instructions for local multi-judge mode."
        )

    if response:
        await ctx.send(
            sender,
            ChatMessage(
                timestamp=datetime.now(tz=timezone.utc),
                msg_id=uuid4(),
                content=[
                    TextContent(type="text", text=response),
                    EndSessionContent(type="end-session"),
                ],
            ),
        )


@chat_proto.on_message(ChatAcknowledgement)
async def handle_acknowledgement(ctx: Context, sender: str, msg: ChatAcknowledgement):
    pass


def generate_orchestrator_response_from_state(state: SharedAgentState) -> str:
    return state.result
