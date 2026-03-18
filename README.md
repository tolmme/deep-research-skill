# Deep Research Skill for Claude Code

Multi-agent deep research with adversarial verification. Drop into `~/.claude/skills/` and run `/deep-research` from any Claude Code session.

## What it does

Decomposes complex questions into parallel sub-queries, dispatches research agents with source diversity mandates, runs adversarial verification (Optimist vs Pessimist vs Fact-Checker), and produces structured reports with inline citations and confidence scores.

```
Phase 0: Parse request, gather context     (~2 min)
Phase 1: Decompose into 4-8 sub-queries    (~1 min)
Phase 2: 3-4 parallel research agents      (~5 min)
Phase 3: Adversarial verification           (~4 min)
Phase 4: Synthesis + report                 (~3 min)
                                      Total: ~15 min
```

## Key features

- **3 modes:** Quick (~5 min, no verification), Standard (~15 min), Deep (~30 min, 6-8 sub-queries)
- **Source diversity:** Each agent gets an exclusive source mandate (government / industry / academic / international) to prevent echo chamber
- **Adversarial verification:** Optimist finds the strongest case, Pessimist searches for counter-evidence with its own WebSearch, Fact-Checker cross-references and assigns confidence
- **Confidence scores:** HIGH (3+ sources agree) / MEDIUM (2 sources) / LOW (single source) / CONTESTED (sources disagree)
- **Token tracking:** Per-phase token estimates with cost breakdown by model (Opus/Sonnet/Haiku)
- **Bilingual:** Russian (Yandex via CLI script) + English (WebSearch)
- **File-based state:** All intermediate evidence saved to output directory for inspection and resume

## Installation

```bash
# Clone into Claude Code skills directory
git clone https://github.com/tolmme/deep-research-skill.git ~/.claude/skills/deep-research
```

That's it. No dependencies, no pip install, no API keys for basic usage.

### Optional: Yandex Search for Russian-language research

```bash
# Install Yandex Cloud CLI
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
yc init

# Set folder ID
export YANDEX_FOLDER_ID=<your-folder-id>

# Test
~/.claude/skills/deep-research/scripts/yandex_search.sh "тестовый запрос"
```

## Usage

From any Claude Code session:

```
/deep-research
```

Or trigger naturally:

- "Research the current state of AI adoption in healthcare"
- "Investigate competitive landscape for dental clinic SaaS in Russia"
- "Deep dive into regulations affecting private clinics"
- "Изучи рынок стоматологических услуг в России"

## Output

Each research run produces:

```
research_output/<topic>_<date>/
  report.md              # Final report with STEP table, citations, confidence
  research_plan.md       # Sub-query decomposition
  sources.json           # All sources with metadata
  token_usage.json       # Cost breakdown per phase
  evidence/
    all_evidence.md      # Raw evidence from all agents
    local_context.md     # Extracted from user's existing files
  verification/
    verification_report.md  # Optimist × Pessimist × Fact-Checker synthesis
```

## Architecture

Built on the [Progressive Disclosure](https://github.com/anthropics/claude-code) pattern for Claude Code skills:

```
SKILL.md          (41 lines)  — entry point, loaded on trigger
references/
  pipeline.md     (913 lines) — full pipeline, loaded on demand
scripts/
  yandex_search.sh            — Yandex Search API via CLI
```

`SKILL.md` is the lightweight trigger. When activated, Claude Code reads `references/pipeline.md` for the full 5-phase pipeline with agent prompts, output formats, and quality rules.

## Design decisions

Based on meta-research of Perplexity, OpenAI Deep Research, and Gemini Deep Research architectures, plus analysis of multi-agent verification patterns (STORM, Tool-MAD, Co-Sight):

| Decision | Why |
|----------|-----|
| Parallel agents (not sequential) | +12.7% quality, -69.6% LLM calls vs sequential |
| "Find bugs" framing for Pessimist | Reduces overconfidence by 15% vs "verify correctness" |
| Source diversity per agent | Prevents echo chamber — agents find different sources |
| Pessimist gets own WebSearch | Can find counter-evidence, not just re-read existing evidence |
| File-based intermediate state | Crash recovery, inspectable evidence trail |
| No Python dependencies | Pure SKILL.md — works on any machine with Claude Code |

## Tested on

- STEP analysis of Russian private healthcare market (47 evidence items, 25+ sources, 17 min)
- Market sizing for dental clinic AI (cross-language RU/EN research)

## Requirements

- [Claude Code](https://claude.ai/code) with Max or API subscription
- Optional: `yc` CLI for Yandex Search (Russian-language research)

## License

MIT
