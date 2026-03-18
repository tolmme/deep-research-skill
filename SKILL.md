---
name: deep-research
description: >
  Multi-agent deep research with adversarial verification and token tracking.
  Parallel sub-queries, Optimist/Pessimist/Fact-Checker debate, structured
  reports with citations and confidence scores. Supports Russian (Yandex) and
  English search. Triggers: deep research, research report, market analysis,
  /deep-research, /research, глубокое исследование, исследование рынка,
  изучи тему, дип ресерч, investigate, competitive analysis, fact-check.
allowed-tools:
  - WebSearch
  - WebFetch
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
---

# Deep Research

Multi-agent pipeline: Planning -> Evidence (parallel) -> Verification (adversarial) -> Report.

## Quick Start

Read `references/pipeline.md` for the full 5-phase pipeline with agent prompts.

## Search

- **English:** WebSearch (built-in)
- **Russian:** `scripts/yandex_search.sh "запрос"` (requires `yc` CLI + YANDEX_FOLDER_ID)
- **Fallback:** WebSearch works for Russian too, just weaker coverage

## Modes

- **Quick** (~5 min): 2 agents, no verification phase. Trigger: "quick research"
- **Standard** (~15 min): 3-4 agents + verification. Default.
- **Deep** (~30 min): 6-8 sub-queries, full verification. Trigger: "deep research"

Full pipeline, agent prompts, output format: `references/pipeline.md`
