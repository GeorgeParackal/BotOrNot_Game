from agents.models.config import JUDGE_ANALYST_SEED
from agents.models.models import SharedAgentState
from uagents import Agent, Context

judge_analyst = Agent(
    name="judge_analyst",
    seed=JUDGE_ANALYST_SEED,
    port=8001,
    mailbox=True,
    publish_agent_details=True,
    network="testnet",
)


def super_cool_judge_analyst_workflow(state: SharedAgentState) -> SharedAgentState:
    """
    In a real implementation, this is where Judge Analyst's specialized agentic workflow lives.
    Think LangGraph state machines, LangChain pipelines, external API calls, tool use,
    RAG retrieval — whatever Judge Analyst is an expert at. They receive the shared state,
    execute their workflow against state.query, and write the final output to
    state.result before returning. That mutation is how their work gets communicated
    back to the judge_skeptic and ultimately to the user.
    """
    state.result = f"Hello, this is Judge Analyst! Your message was: {state.query}"
    return state


@judge_analyst.on_message(SharedAgentState)
async def handle_message(ctx: Context, sender: str, state: SharedAgentState):
    ctx.logger.info(f"Received state from judge_skeptic: session={state.chat_session_id}, query={state.query!r}")
    state = super_cool_judge_analyst_workflow(state)
    await ctx.send(sender, state)


if __name__ == "__main__":
    judge_analyst.run()
