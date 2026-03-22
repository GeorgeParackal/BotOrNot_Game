# BotOrNot — Judge Agents

Three AI judge agents for the BotOrNot game, built with [Fetch.ai uAgents](https://fetch.ai/docs/guides/agents/getting-started/create-a-uagent).

Each judge has a different personality and scoring style. They all receive a game prompt + player response and return a score (0–100 AI likeness) with a one-sentence reaction.

---

## The 3 Judges

| File | Name | Personality | Scoring Style |
|---|---|---|---|
| `judge_analyst.py` | The Analyst | Cold, clinical, data-driven | Strict pattern matching — passive voice, hedging, formal vocab |
| `judge_hype_host.py` | The Hype Host | Loud, dramatic gameshow energy | Rewards buzzwords and soulless corporate speak |
| `judge_skeptic.py` | The Skeptic | Paranoid, hard to fool | Harshest scorer — any hint of humanity = low score |

---

## Setup (you need a Fetch.ai account + Gemini API key)

### 1. Accounts needed
- **Fetch.ai**: Sign up at [fetch.ai](https://fetch.ai) — needed to register agents on Agentverse
- **Google AI Studio**: Get a free Gemini API key at [aistudio.google.com](https://aistudio.google.com)

### 2. Install dependencies
```bash
cd agents
pip install -r requirements.txt
```

### 3. Create your .env
```bash
cp .env.example .env
# then edit .env and paste your Gemini API key
```

### 4. Change the seed phrases
Before running, open each agent file and change the `seed=` value to something unique to you.
The seed is what generates your agent's address — if two people use the same seed they get the same address.

```python
# Example — change this in each file
agent = Agent(
    seed="your own unique phrase here",  # <-- change this
    ...
)
```

### 5. Run an agent
```bash
python judge_analyst.py
```

On startup it prints something like:
```
INFO: The Analyst is online: agent1q2abc...xyz
```

Copy that address — that's what goes into the game server to route scoring to this judge.

### 6. Register on Agentverse (makes it discoverable)
- Go to [agentverse.ai](https://agentverse.ai)
- Connect your Fetch.ai account
- Register your agent using the address printed on startup

---

## How it plugs into the game

Each judge exposes two uAgent models:

```python
class ScoreRequest(Model):
    prompt: str      # the game prompt shown to players
    response: str    # the player's submitted response

class ScoreResponse(Model):
    score: int       # 0-100, how AI-like the response is
    reasoning: str   # one sentence reaction from the judge
```

The game server queries whichever judges are active each round and averages (or picks) their scores.

---

## Running multiple judges
Each agent runs on a different port (8010, 8011, 8012) so you can run all three at once:

```bash
# three separate terminals
python judge_analyst.py
python judge_hype_host.py
python judge_skeptic.py
```

---

## Pipeline overview
```
Roblox Game Server
      |
      | ScoreRequest (prompt + player response)
      v
  uAgents query  ──>  judge_analyst    (port 8010)
                 ──>  judge_hype_host  (port 8011)
                 ──>  judge_skeptic    (port 8012)
      |
      | ScoreResponse (score + reasoning)
      v
  Game Server averages scores → checks threshold → updates player lives
```
