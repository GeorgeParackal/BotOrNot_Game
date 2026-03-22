# AI Answer Evaluation System with Personalized Judge Agents

## Project Overview

This project is an innovative AI-powered evaluation system that combines **Roblox Studio game development** with **uAgents framework** and **Google Gemini API** to create an interactive experience where players write answers to prompts and receive feedback from three distinct AI judge personalities.

The system evaluates whether player answers are AI-generated or human-written, providing both quantitative scores and qualitative feedback from three unique judge perspectives: The Analyst (clinical, data-driven), The Hype Host (dramatic, entertaining), and The Skeptic (paranoid, suspicious).

---

## Table of Contents

1. [Project Purpose](#project-purpose)
2. [Architecture Overview](#architecture-overview)
3. [Project Components](#project-components)
4. [Gemini Agents Integration](#gemini-agents-integration)
5. [Judge System & Personalities](#judge-system--personalities)
6. [How Judges Evaluate Answers](#how-judges-evaluate-answers)
7. [Technology Stack](#technology-stack)
8. [Setup & Configuration](#setup--configuration)

---

## Project Purpose

The core purpose of this project is to:

- **Distinguish AI-generated content from human-written responses** using advanced language models
- **Provide multi-perspective feedback** by having three judges evaluate the same answer with different personalities and criteria
- **Create an interactive gaming experience** in Roblox where players engage with creative prompts and receive instant AI-powered evaluation
- **Demonstrate agent-based architecture** by using separate uAgents for each judge personality, each with their own Gemini API calls
- **Reduce API costs** by implementing intelligent model selection (gemini-2.5-flash-lite as primary) and local multi-judge orchestration in skeptic agent

---

## Architecture Overview

The system is divided into three main layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    ROBLOX STUDIOS (Frontend)                │
│  - Player GUI for prompts and answers                       │
│  - Answer submission and result display                     │
│  - Judge feedback rendering (Overview + Judges tabs)        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ HTTP REST & Remote Server Calls
                     ▼
┌─────────────────────────────────────────────────────────────┐
│            LUAU SERVER BACKEND (init.server.luau)           │
│  - Prompt generation via Gemini API (GEMINI_API_KEY)        │
│  - Answer analysis via Gemini API (GEMINI_API_KEY2)         │
│  - Judge orchestration via judge_skeptic REST endpoint      │
│  - RemoteFunction handlers for client-server communication  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ HTTP REST (/run_judges endpoint)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         PYTHON UAGENTS (Backend Orchestration)              │
│                   judge_skeptic Agent                        │
│  - Receives /run_judges POST requests                       │
│  - Calls generate_all_judges_response()                     │
│  - One Gemini request for all 3 judge personalities         │
│  - Returns distinct ratings and personalized responses      │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Components

### 1. **Roblox Studio Client** (`src/client/init.client.luau`)
- **Purpose**: User interface for player interaction
- **Features**:
  - Prompt display and request handling
  - Answer input box with text submission
  - Results display with two tabs:
    - Overview: Overall AI-likelihood percentage and explanation
    - Judges: Individual judge ratings and responses
  - Dynamic UI panel creation with proper styling

### 2. **Roblox Studio Server** (`src/server/init.server.luau`)
- **Purpose**: Handles game logic, Gemini API calls, and judge orchestration
- **Key Functions**:
  - `requestGeminiPrompt()`: Fetches random prompts using Gemini (cheaper, creative generation)
  - `requestAnswerEvaluation()`: Analyzes player answers for AI likelihood using Gemini
  - `requestJudgeMessages()`: Calls HTTP endpoint to judge_skeptic agent REST API
  - `evaluateAnswerRemote.OnServerInvoke()`: Main entry point for answer submissions
- **API Keys Used**:
  - `GEMINI_API_KEY`: Prompt generation
  - `GEMINI_API_KEY2`: Answer analysis and judge scoring (dedicated key for answer-judging path)

### 3. **Python Judge Agents** (`agents/judge_*/judge_*_fetchai_wrapped_agent.py`)

Three distinct uAgents, each representing a different evaluation personality:

#### **Judge Skeptic** (`agents/judge_skeptic/`)
- **Role**: Orchestrator and local multi-judge generator
- **Personality**: Paranoid, suspicious, hard to fool
- **Key Features**:
  - REST endpoint `/run_judges` that accepts POST requests with answer + metadata
  - `generate_all_judges_response()`: Single Gemini call that returns all three judge outputs in one JSON response
  - Calls GEMINI_API_KEY2 exclusively for judge scoring
  - Logs rate-limiting and fallback behavior for debugging
  - Normalizes judge ratings to ensure distinctness (no duplicate scores)

#### **Judge Analyst** (`agents/judge_analyst/`)
- **Role**: Specialized evaluator (no longer used in REST flow, kept for legacy support)
- **Personality**: Cold, clinical, data-driven
- **Focus**: Passive voice, hedging language, structured analysis, lack of emotional tone

#### **Judge Hype Host** (`agents/judge_hype_host/`)
- **Role**: Specialized evaluator (no longer used in REST flow, kept for legacy support)
- **Personality**: Loud, dramatic, gameshow energy
- **Focus**: Buzzwords, corporate speak, lack of soul; roasts robotic-sounding text

### 4. **Models & Configuration** (`agents/models/`)
- `config.py`: Environment configuration and agent addresses
- `models.py`: Pydantic data models for inter-agent communication
- `state_service.py`: Stateful session management for multi-turn conversations

- **Environment Variables** (`.env`):
  ```
  GEMINI_API_KEY=<primary_api_key>
  GEMINI_API_KEY2=<answer_judging_key>
  JUDGE_ANALYST_SEED_PHRASE=<seed>
  JUDGE_HYPE_HOST_SEED_PHRASE=<seed>
  JUDGE_SKEPTIC_SEED_PHRASE=<seed>
  JUDGE_SKEPTIC_ADDRESS=agent1q0xqqcnmcthhzpzz3zntngrpx78els543405c3n8nlvvv3m5ncjn6py5v7t
  JUDGE_HYPE_HOST_ADDRESS=agent1qwgcckmzqwc3ln3f7gvylzeh0ms2pkuscw4jyhfz7hhmkanntxh52uva47p
  JUDGE_ANALYST_ADDRESS=agent1q2gql9xwl5uk7quj0rq54wz80ej43xz5jv9s3n8pzys4xqdvhfsyy6hjtq5
  ```

---

## Gemini Agents Integration

### Overview

This project leverages **Google Gemini API** and **uAgents framework** to create autonomous, specialized agents that evaluate answers with distinct personalities.

### Why Agents?

**uAgents** provides:
- **Autonomous execution**: Each judge runs independently with its own logic
- **Protocol-based communication**: Structured messaging between agents (Query/Message protocols)
- **Network registration**: Agents can be discovered and invoked via addresses
- **Scalability**: New judges can be added without modifying core orchestration

**Gemini API** provides:
- **Cost-efficient models**: gemini-2.5-flash-lite at $0.10/$0.40 per 1M tokens (input/output)
- **Multi-turn context**: Maintains conversation state across requests
- **JSON output mode**: Structured responses matching our evaluation schema

### Integration Flow

```
Player submits answer
        │
        ▼
Roblox Server (init.server.luau)
        │
        ├─► Calls Gemini to analyze AI-likelihood (GEMINI_API_KEY2)
        │   Returns: {ai_generated_percent, explanation}
        │
        └─► HTTP POST to judge_skeptic:8003/run_judges
            {
              player_name: "PlayerName",
              player_user_id: 1234,
              prompt: "...",
              answer: "...",
              ai_generated_percent: 75,
              gemini_explanation: "..."
            }
                    │
                    ▼
            judge_skeptic REST Endpoint
                    │
                    ├─► generate_all_judges_response(req)
                    │   │
                    │   ├─► Calls Gemini (GEMINI_API_KEY2)
                    │   │   Prompt includes instructions for all 3 personas
                    │   │
                    │   └─► Returns parsed JSON:
                    │       {
                    │         "analyst": {rating: 65, response: "..."},
                    │         "hype_host": {rating: 72, response: "..."},
                    │         "skeptic": {rating: 58, response: "..."}
                    │       }
                    │
                    └─► Normalizes ratings (ensure distinct values)
                    └─► Returns RunJudgesResponse
                            │
                            ▼
            Roblox Server receives response
                    │
                    └─► Forwards to client UI
                            │
                            ▼
            Roblox Client renders judge feedback
```

### Model Selection Strategy

We use **intelligent fallback** for cost and reliability:

1. **Primary**: `gemini-2.5-flash-lite` — Cheapest stable model ($0.10/$0.40)
2. **Fallback**: `gemini-3.1-flash-lite-preview` — Newer preview option if primary fails
3. **Last resort**: `gemini-2.5-flash` — Full-featured model for critical requests

This approach:
- Minimizes API costs (2.5-flash-lite is 2-10x cheaper than standard models)
- Provides redundancy (falls back if model is unavailable)
- Matches the 404 error fix (removed deprecated `gemini-2.5-flash-lite-preview`)

---

## Judge System & Personalities

### Judge Personalities

Each judge evaluates the same answer through a completely different lens:

#### **The Analyst** (judge_analyst)
- **Personality**: Cold, clinical, data-driven
- **Tone**: Measured, hedging, passive voice
- **Looks for**: 
  - Structured thinking
  - Lack of emotional language
  - Measured phrasing
  - Controlled vocabulary
- **Example output**: "Analyst scan: score 72%. I detect controlled structure and measured phrasing, but the emotional signature still needs calibration."

#### **The Hype Host** (judge_hype_host)
- **Personality**: Loud, dramatic, gameshow narrator
- **Tone**: Energetic, buzzword-heavy, entertainment-focused
- **Looks for**:
  - Corporate/marketing language
  - Lack of soul or authenticity
  - Over-the-top enthusiasm
  - Robotic promotional tone
- **Example output**: "Hype Host here, and this one clocks in at 68% robot energy! Give me more synthetic swagger and less human sparkle next round!"

#### **The Skeptic** (judge_skeptic)
- **Personality**: Paranoid, suspicious, hard to convince
- **Tone**: Dismissive, always looking for proof of humanity
- **Looks for**:
  - Slips of personality
  - Humor or real-world experience
  - Any human "fingerprints"
  - Proof of authentic thinking
- **Example output**: "Skeptic verdict at 45%: not convinced yet. One human-sounding slip and the mask comes off."

### How Personality Assignment Works

**Before (Remote Agent Architecture)**:
- Three separate agents (analyst, hype_host, skeptic) running on different ports
- Each received queries and independently called Gemini
- This caused:
  - Envelope signature errors due to mailbox delivery failures
  - 45+ second delays between judge responses (agent-to-agent latency)
  - Higher API costs (3 separate Gemini calls per evaluation)

**Current (Local Multi-Judge Architecture)**:
- **Single Gemini call** in `judge_skeptic` agent that generates all 3 personalities at once
- Gemini prompt explicitly instructs to generate outputs for "analyst", "hype_host", and "skeptic" keys
- Each personality receives its assigned persona in the prompt:
  ```python
  "Persona rules:\n"
  "- analyst: Cold, clinical, data-driven. Focus on passive voice, hedging language, structure, and emotional flatness.\n"
  "- hype_host: Loud, dramatic, gameshow energy. Roast robotic tone with punchy flair.\n"
  "- skeptic: Paranoid, suspicious, hard to fool. Assume human until proven otherwise.\n"
  ```
- Responses are parsed from JSON and returned with distinct ratings normalized by `ensure_distinct_judge_ratings()` helper

### Why This Design Is Better

1. **Faster**: One API request instead of three queued requests
2. **Cheaper**: Single Gemini call vs. three calls (up to 3x cost reduction)
3. **Reliable**: No agent-to-agent mailbox issues
4. **Distinct Ratings**: Built-in normalization ensures judges don't all give the same score
5. **Personality Consistent**: All judges evaluate the same answer in the same context

---

## How Judges Evaluate Answers

### Step-by-Step Evaluation Process

#### **Phase 1: Initial Analysis (Roblox Server)**
```
Player submits answer
    │
    └─► Roblox server calls Gemini with:
        • Player's prompt
        • Player's answer
        • System instruction for AI-likelihood analysis
        
        Gemini returns:
        • ai_generated_percent (0-100)
        • explanation (one paragraph)
```

#### **Phase 2: Judge Orchestration (judge_skeptic Agent)**
```
Server sends /run_judges POST request with:
  {
    player_name: "PlayerName",
    player_user_id: 1234,
    prompt: "Your original prompt",
    answer: "The player's answer",
    ai_generated_percent: 75,
    gemini_explanation: "Reason from Phase 1"
  }
    │
    └─► judge_skeptic receives request
        │
        ├─► Checks if GEMINI_API_KEY2 is available
        │
        ├─► Calls generate_all_judges_response(req)
        │   │
        │   └─► Builds Gemini prompt with:
        │       • Full persona descriptions (analyst, hype_host, skeptic)
        │       • The player's prompt and answer
        │       • Gemini's initial AI-likelihood score
        │       • Instructions for JSON output format
        │   
        │   └─► Makes single HTTP request to Gemini API
        │       Model: gemini-2.5-flash-lite (or fallback)
        │       Response format: JSON with analyst/hype_host/skeptic keys
        │
        ├─► Parses JSON response
        │   └─► Extracts {response, rating} for each persona
        │
        ├─► Normalizes ratings via ensure_distinct_judge_ratings()
        │   └─► Ensures no two judges have the same score
        │
        └─► Returns RunJudgesResponse:
            {
              skeptic_result: "...",
              skeptic_rating: 58,
              analyst_result: "...",
              analyst_rating: 65,
              hype_host_result: "...",
              hype_host_rating: 72
            }
```

#### **Phase 3: Results Display (Roblox Client)**
```
Roblox server forwards judge responses to client
    │
    └─► Client renders two tabs:
        
        1. OVERVIEW TAB
           • AI Generated Likelihood: 75%
           • Reason: <gemini_explanation>
        
        2. JUDGES TAB
           • [The Analyst] Rating: 65%
            <judge response>
           
           • [The Hype Host] Rating: 72%
            <judge response>
           
           • [The Skeptic] Rating: 58%
            <judge response>
```

### Evaluation Criteria

Each judge evaluates based on the initial AI-likelihood score but applies their own lens:

| Criterion | Analyst | Hype Host | Skeptic |
|-----------|---------|-----------|---------|
| **Baseline** | Uses AI score as-is | Adds +10 to score (assumes more robotic) | Subtracts -10 from score (assumes human) |
| **Language** | Passive voice, hedging | Corporate buzzwords, enthusiasm | Real-world details, personality |
| **Emotion** | Looks for emotional flatness | Looks for synthetic energy | Looks for authentic emotion |
| **Tone** | Clinical, measured | Loud, entertaining roast | Paranoid, suspicious |
| **Report Length** | 1-2 clinical sentences | 1-2 energetic sentences | 1-2 challenging sentences |

---

## Technology Stack

### Frontend
- **Roblox Studio** (Luau scripting language)
- **RemoteFunction** API for client-server communication
- Custom UI components (TextLabels, TextBoxes, Buttons with UICorner styling)

### Backend (Game Server)
- **Luau** (Roblox scripting) for game logic
- **HttpService** for REST calls to judge agents
- **Google Gemini API** for prompt generation and answer analysis

### Agent Infrastructure
- **Python 3.12+**
- **uAgents** framework (Fetch.ai)
  - Agent registration and mailbox setup
  - Protocol definitions (on_rest_post, on_message, on_query)
  - Agent-to-agent communication
- **FastAPI** (wrapped by uAgents) for REST endpoints
- **Pydantic** for data validation

### APIs
- **Google Gemini API** (gemini-2.5-flash-lite, gemini-3.1-flash-lite-preview, gemini-2.5-flash)
  - Text generation for prompts
  - Text generation for answer analysis
  - JSON-mode responses for structured output

### Environment Management
- **Python venv** for Python dependencies
- **.env file** for API keys and agent configuration
- **python-dotenv** for environment variable loading

### Logging & Debugging
- **Python logging** module for judge agent diagnostics
- Rate-limit detection and retry-after logging
- HTTP status code logging (429 for rate limits, 404 for missing models)

---

## Setup & Configuration

### Prerequisites
- Roblox Studio (installed)
- Python 3.12+ with venv
- Google Gemini API keys (2 separate keys recommended)
- Internet connection for API calls

### Installation

1. **Configure Python Environment**
   ```bash
   cd "c:\Users\Dogyum\Documents\VsCode adon"
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r agents/requirements.txt
   ```

2. **Set Environment Variables** (`.env` file)
   ```
   GEMINI_API_KEY=<your_primary_key>
   GEMINI_API_KEY2=<your_answer_judging_key>
   JUDGE_ANALYST_SEED_PHRASE=<seed>
   JUDGE_HYPE_HOST_SEED_PHRASE=<seed>
   JUDGE_SKEPTIC_SEED_PHRASE=<seed>
   JUDGE_SKEPTIC_ADDRESS=agent1q0xqqcnmcthhzpzz3zntngrpx78els543405c3n8nlvvv3m5ncjn6py5v7t
   JUDGE_HYPE_HOST_ADDRESS=agent1qwgcckmzqwc3ln3f7gvylzeh0ms2pkuscw4jyhfz7hhmkanntxh52uva47p
   JUDGE_ANALYST_ADDRESS=agent1q2gql9xwl5uk7quj0rq54wz80ej43xz5jv9s3n8pzys4xqdvhfsyy6hjtq5
   ```

3. **Start Judge Agent**
   ```bash
   .venv\Scripts\activate
   cd agents
   python -m judge_skeptic.judge_skeptic_fetchai_wrapped_agent
   ```
   The agent will start on `http://localhost:8003` with REST endpoint at `/run_judges`

4. **Run Roblox Game**
   - Open the `.rbxl` or `.rbxm` file in Roblox Studio
   - Run the game in Studio (F5 or Play button)
   - Click "Play" button in game to trigger prompt generation
   - Type answer and submit

### Rate Limiting & Model Fallback

- **Primary model**: `gemini-2.5-flash-lite` (cheapest)
- **Fallback chain**: `gemini-3.1-flash-lite-preview` → `gemini-2.5-flash`
- **Rate limit handling**: Automatic retry with exponential backoff
- **Logging**: Check console for `[judge_skeptic] Rate limited by Gemini` messages

---

## Key Features & Design Decisions

### ✅ Single Gemini Call for All Judges
- Reduced API calls from 3 to 1 per evaluation
- Faster response times
- Lower operational costs

### ✅ Distinct Judge Ratings
- Built-in normalization ensures different scores
- Each judge brings unique evaluation perspective
- Prevents monotonous identical ratings

### ✅ Two Separate API Keys
- `GEMINI_API_KEY`: Prompt generation (creative, lower cost)
- `GEMINI_API_KEY2`: Answer analysis & judging (critical path, isolated quota)

### ✅ Local Orchestration in Skeptic Agent
- Eliminates agent-to-agent mailbox delivery failures
- No "Envelope signature is missing" errors
- Synchronous execution (no 45+ second delays)

### ✅ Rate Limiting & Fallback
- Automatic retry with model fallback
- JSON response mode for structured parsing
- Explicit logging of rate limit conditions

---

## Troubleshooting

### Issue: "GEMINI_API_KEY2 is missing"
- **Solution**: Add `GEMINI_API_KEY2` to `.env` file

### Issue: 404 errors on judge requests
- **Cause**: Using deprecated model name (`gemini-2.5-flash-lite-preview`)
- **Solution**: Updated to valid models (`gemini-2.5-flash-lite`, `gemini-3.1-flash-lite-preview`)

### Issue: AI likelihood always returns 95%
- **Cause**: Parser was too permissive and picked up wrong numbers
- **Solution**: Tightened parser to only accept `ai_generated_percent` key from JSON

### Issue: Similar ratings from all judges
- **Cause**: Missing normalization logic
- **Solution**: Added `ensure_distinct_judge_ratings()` function to guarantee unique values

---

## Future Enhancements

- WebSocket support for real-time judge feedback
- Persistent storage of evaluation history
- Multi-language support for judge personalities
- Custom personality creation
- Leaderboard system based on "humanness" scores
- Batch evaluation for multiple answers

---

## License & Attribution

This project combines:
- **Roblox Studio API** for game development
- **uAgents framework** (Fetch.ai) for autonomous agent architecture
- **Google Gemini API** for natural language processing

---

## Contact & Support

For issues or questions, refer to:
- Agent logs: Check terminal output for `[judge_*]` log messages
- Roblox Output: Check Studio output panel for Luau debug messages
- Rate limiting: Monitor `Retry-After` headers in HTTP responses

---

**Last Updated**: March 22, 2026
