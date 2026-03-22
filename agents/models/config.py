import os
from dotenv import find_dotenv, load_dotenv
from uagents_core.identity import Identity

load_dotenv(find_dotenv())

JUDGE_ANALYST_SEED = os.getenv("JUDGE_ANALYST_SEED_PHRASE")
JUDGE_HYPE_HOST_SEED = os.getenv("JUDGE_HYPE_HOST_SEED_PHRASE")
JUDGE_SKEPTIC_SEED = os.getenv("JUDGE_SKEPTIC_SEED_PHRASE")

JUDGE_ANALYST_ADDRESS = os.getenv(
	"JUDGE_ANALYST_ADDRESS",
	"agent1q2gql9xwl5uk7quj0rq54wz80ej43xz5jv9s3n8pzys4xqdvhfsyy6hjtq5",
)
JUDGE_HYPE_HOST_ADDRESS = os.getenv(
	"JUDGE_HYPE_HOST_ADDRESS",
	"agent1qwgcckmzqwc3ln3f7gvylzeh0ms2pkuscw4jyhfz7hhmkanntxh52uva47p",
)
JUDGE_SKEPTIC_ADDRESS = os.getenv(
	"JUDGE_SKEPTIC_ADDRESS",
	"agent1q0xqqcnmcthhzpzz3zntngrpx78els543405c3n8nlvvv3m5ncjn6py5v7t",
)
