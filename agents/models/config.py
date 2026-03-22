import os
from dotenv import find_dotenv, load_dotenv
from uagents_core.identity import Identity

load_dotenv(find_dotenv())

JUDGE_ANALYST_SEED = os.getenv("JUDGE_ANALYST_SEED_PHRASE")
JUDGE_HYPE_HOST_SEED = os.getenv("JUDGE_HYPE_HOST_SEED_PHRASE")
JUDGE_SKEPTIC_SEED = os.getenv("JUDGE_SKEPTIC_SEED_PHRASE")

JUDGE_ANALYST_ADDRESS = Identity.from_seed(seed=JUDGE_ANALYST_SEED, index=0).address
JUDGE_HYPE_HOST_ADDRESS = Identity.from_seed(seed=JUDGE_HYPE_HOST_SEED, index=0).address
