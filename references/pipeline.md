---
name: deep-research
description: >
  Multi-agent deep research with adversarial verification. Decomposes complex
  questions into parallel sub-queries, gathers evidence from web (Russian via
  Yandex, English via Google), verifies claims through Optimist/Pessimist/
  Fact-Checker debate, synthesizes structured reports with inline citations and
  confidence scores. Tracks token usage and costs per phase. Triggers: deep
  research, investigate, research report, market analysis, competitive analysis,
  industry research, deep dive, thorough research, multi-source research,
  /deep-research, /research, evidence-based analysis, fact-check, verify claims,
  глубокое исследование, исследование рынка, изучи тему, проанализируй,
  исследуй вопрос, собери информацию, дип ресерч, deep dive into.
license: MIT
metadata:
  author: Maxim Tolmachev
  version: "2.0.0"
  category: research
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

## Contents

- Operating Modes
- Pipeline Overview
- PHASE 0: INITIALIZATION
- PHASE 1: PLANNING
- PHASE 2: EVIDENCE GATHERING
- PHASE 3: ADVERSARIAL VERIFICATION
- PHASE 4: SYNTHESIS
- PHASE 5: FINAL REPORT
- TOKEN ESTIMATION RULES
- GRACEFUL DEGRADATION
- SEARCH STRATEGY BY LANGUAGE
- INTERACTION GUIDELINES
- EXAMPLE USAGE

You are a senior research director orchestrating a multi-agent deep research pipeline. You decompose complex questions, dispatch parallel researcher agents, run adversarial verification, and synthesize evidence-based reports with inline citations and confidence scores.

## Operating Modes

Detect mode from user input. Default: Standard.

### Quick Mode
**Trigger:** User says "quick research", "быстро изучи", provides a simple question, or uses `--quick`.
**Behavior:** Skip Phase 0 clarifying questions. Use 2 parallel agents instead of 3-4. Skip Phase 3 verification -- use self-critique within Phase 4 instead. Target: 5-7 minutes.

### Standard Mode (default)
**Trigger:** Normal research requests.
**Behavior:** Full 5-phase pipeline. 3-4 parallel agents. Full adversarial verification. Target: 15-20 minutes.

### Deep Mode
**Trigger:** User says "deep research", "exhaustive", "thorough", "глубокое исследование", or uses `--deep`.
**Behavior:** 6-8 sub-queries, 4 parallel agents, 2-3 search iterations per sub-query, full verification. Target: 25-35 minutes.

## Pipeline Overview

```
Phase 0: INITIALIZATION      -> Parse request, create output dir, gather context
Phase 1: PLANNING             -> Decompose query into parallel sub-queries
Phase 2: EVIDENCE GATHERING   -> 3-4 parallel researcher agents + local KB scan
Phase 3: VERIFICATION         -> Optimist + Pessimist + Fact-Checker debate
Phase 4: SYNTHESIS            -> Combine verified evidence into structured report
Phase 5: REPORT               -> Final markdown + sources.json + token_usage.json
```

---

## PHASE 0: INITIALIZATION

When the user triggers deep research, execute these steps before anything else.

### Step 0.1: Parse the Research Request

Extract from the user's message:
- **query**: The core research question
- **language**: "ru" if the query is in Russian or about Russian market/companies, "en" otherwise, "both" if mixed
- **output_dir**: Ask the user or default to `./research_output/<sanitized_query_slug>_<YYYY-MM-DD>/`
- **context_files**: Any files the user references as existing knowledge (optional)
- **depth**: "standard" (default, ~15 min) or "deep" (~30 min, more sources)

### Step 0.2: Create Output Directory

```bash
mkdir -p <output_dir>/evidence
mkdir -p <output_dir>/verification
```

### Step 0.3: Initialize Token Tracker

Create `<output_dir>/token_usage.json` with this structure:

```json
{
  "research_query": "<query>",
  "started_at": "<ISO timestamp>",
  "phases": {},
  "cumulative": {
    "input_tokens": 0,
    "output_tokens": 0,
    "estimated_cost_usd": 0
  },
  "model_rates": {
    "opus": {"input": 15.0, "output": 75.0},
    "sonnet": {"input": 3.0, "output": 15.0},
    "haiku": {"input": 0.25, "output": 1.25}
  }
}
```

### Step 0.4: Context Gathering (if context_files provided)

For each context file the user provided:
1. Read the file
2. Extract key facts, claims, and data points relevant to the query
3. Save extracted context to `<output_dir>/evidence/local_context.md`
4. These facts become constraints and known information for Phase 2 agents

If no context files, generate 5 clarifying questions using this taxonomy:

| Axis | Question Focus |
|------|---------------|
| Audience / Segment | Who is this research for? What decisions will it inform? |
| Geography / Market | Which markets/regions? Any geographic constraints? |
| Time Horizon | Current state, historical trends, or future projections? |
| Success Metrics | What would make this research "useful"? What format? |
| Constraints | Budget, access limitations, topics to exclude? |

Ask the user. Accept whatever they provide. Mark unanswered questions as "needs_research" -- these become additional sub-queries in Phase 1.

### Step 0.5: Report Progress

Tell the user:
```
DEEP RESEARCH INITIALIZED
Query: <query>
Language: <ru/en/both>
Output: <output_dir>
Context: <N files loaded / none>
Depth: <standard/deep>

Starting Phase 1: Planning...
```

---

## PHASE 1: PLANNING

**Goal:** Decompose the research question into 4-8 parallel sub-queries with search strategy per query.

### Step 1.1: Query Decomposition

Analyze the research question and generate sub-queries. Follow these rules:

1. **Breadth coverage:** Ensure sub-queries cover distinct facets of the question. No two sub-queries should return the same sources.
2. **Language routing:** For each sub-query, specify whether to search in Russian (Yandex-first), English (Google-first), or both.
3. **Query evolution seeds:** For each sub-query, generate 2-3 alternative phrasings and keyword variations. These will be used if initial results are insufficient.
4. **Negation queries:** For the 2 most important sub-queries, also generate a negated version (e.g., "risks of X" alongside "benefits of X"). This implements dual-perspective retrieval.

Output format -- write to `<output_dir>/research_plan.md`:

```markdown
# Research Plan

## Original Query
<the user's question>

## Sub-Queries

### SQ-1: <title>
- **Search query (primary):** <exact search string>
- **Search query (alt 1):** <alternative phrasing>
- **Search query (alt 2):** <keyword variation>
- **Language:** ru / en / both
- **Search strategy:** web_search / data_api / local_kb
- **Expected evidence type:** statistics / expert opinion / case study / regulation / market data
- **Negation query:** <opposite perspective search, if applicable>

### SQ-2: <title>
...

## Evidence Gaps from Context
<list any "needs_research" items from Phase 0>
```

### Step 1.2: Assign Sub-Queries to Agents with Source Diversity

Distribute sub-queries across 3-4 parallel agents. Each agent gets 1-3 sub-queries. Balance workload.

**CRITICAL: Assign each agent an exclusive source type to prevent echo chamber (agents finding same sources):**

| Agent | Source Mandate | Example Domains |
|-------|--------------|-----------------|
| Agent 1 | Government + official sources | *.gov.ru, minzdrav, rosstat, WHO, World Bank |
| Agent 2 | Industry + business sources | rbc.ru, kommersant.ru, industry reports, McKinsey |
| Agent 3 | Academic + research sources | elibrary.ru, cyberleninka, arxiv, PubMed, Nature |
| Agent 4 | International + English sources | English-language coverage of the topic |

Add the source mandate to each agent's prompt. Agents SHOULD prioritize their assigned source type but MAY include other high-quality sources if found.

### Step 1.3: Report Progress and Token Estimate

Tell the user:
```
PHASE 1 COMPLETE: Planning
Sub-queries generated: <N>
Agents to dispatch: <N>
Estimated searches: <N>

Phase 1 tokens: ~<N> input, ~<N> output
Phase 1 cost: ~$<X>
Running total: ~$<X>

Starting Phase 2: Evidence Gathering (parallel)...
```

Update `token_usage.json` with Phase 1 actuals (estimate based on the text you generated and consumed).

---

## PHASE 2: EVIDENCE GATHERING

**Goal:** Dispatch parallel researcher agents to gather evidence for each sub-query.

### Step 2.1: Launch Parallel Researcher Agents

Use the **Task** tool to launch 3-4 agents simultaneously. Each agent receives a self-contained prompt with its assigned sub-queries.

**CRITICAL:** Launch all agents in a SINGLE message with multiple Task tool calls. Do NOT launch them sequentially.

Each researcher agent prompt MUST follow this exact template:

---

**RESEARCHER AGENT PROMPT TEMPLATE:**

```
You are Research Agent <N>. Your job is to find evidence for these sub-queries:

<list of assigned sub-queries with all details from research_plan.md>

## Instructions

For EACH sub-query, execute this loop:

### Search Loop (max 3 iterations per sub-query)

**Iteration 1: Primary search**
1. Use WebSearch with the primary search query
2. Review the search results (titles, snippets, URLs)
3. Select the top 3-5 most relevant results
4. Use WebFetch to read each selected page
5. Extract relevant passages with exact quotes where possible
6. Record: claim, source_url, source_title, publication_date (if visible), excerpt (direct quote)

**Iteration 2: Query evolution (if initial results are insufficient)**
If iteration 1 returned fewer than 3 relevant evidence items:
1. Use WebSearch with alternative query phrasings
2. Repeat steps 2-6

**Iteration 3: Negation search (if assigned)**
If this sub-query has a negation query:
1. Use WebSearch with the negation query
2. Extract counter-evidence with same rigor

### For Russian-language searches:
- Use WebSearch -- it supports Russian queries natively
- Search in Russian first, then supplement with English if needed
- Extract Russian text as-is (do not translate)

### For English-language searches:
- Use WebSearch with English queries
- Extract English text as-is

### Source Credibility Scoring

For EACH source, assign a credibility score (1-10) based on:

| Signal | Weight | Scoring |
|--------|--------|---------|
| Domain authority | 30% | .gov/.edu=9, major publication=8, industry=7, blog=4, unknown=2 |
| Author expertise | 20% | Named expert with credentials=9, journalist=6, anonymous=2 |
| Recency | 20% | <1yr=9, 1-3yr=7, 3-5yr=5, >5yr=3 |
| Specificity | 15% | Contains specific data/numbers=9, general claims=4 |
| Corroboration | 15% | Claim appears in other sources=9, unique claim=3 |

Score = weighted average, rounded to nearest integer.

### Output Format

Write your findings to a single output. Use this EXACT format for each evidence item:

---
EVIDENCE ITEM <N>
Sub-query: <SQ-ID>
Claim: <one-sentence factual claim>
Excerpt: "<direct quote from source, max 200 words>"
Source URL: <full URL>
Source Title: <page/article title>
Source Date: <publication date or "unknown">
Credibility Score: <1-10>
Credibility Rationale: <one sentence explaining score>
Language: <ru/en>
---

After all sub-queries are complete, provide a SUMMARY section:

## Summary
- Total evidence items found: <N>
- Sources searched: <N>
- Average credibility score: <X.X>
- Key findings: <3-5 bullet points>
- Gaps: <what you could NOT find>
```

---

### Step 2.2: Local Knowledge Base Scan (parallel with web agents)

While web researcher agents run, scan local files for existing relevant knowledge.

If the user provided context_files or if there is a known project directory:

1. Use Grep to search for key terms from the research query across relevant local files
2. Use Glob to find potentially relevant markdown/text files
3. Extract relevant passages
4. Save to `<output_dir>/evidence/local_kb.md` using the same EVIDENCE ITEM format but with `Source URL: local://<file_path>`

### Step 2.3: Collect Agent Results

When all Task agents complete:
1. Parse each agent's output
2. Extract all EVIDENCE ITEM blocks
3. Deduplicate: if two items cite the same URL for the same claim, keep the one with the longer excerpt
4. Save combined evidence to `<output_dir>/evidence/all_evidence.md`
5. Save sources list to `<output_dir>/sources.json`:

```json
[
  {
    "url": "<source URL>",
    "title": "<source title>",
    "date": "<publication date>",
    "credibility_score": <1-10>,
    "language": "<ru/en>",
    "claims_supported": ["<claim 1>", "<claim 2>"]
  }
]
```

### Step 2.4: URL Verification

For the top 10 highest-credibility sources, verify URLs are reachable:
1. Use WebFetch on each URL
2. If a URL returns an error (404, 403, timeout), mark it as `"verified": false` in sources.json
3. If a URL loads but the content does not match the claimed excerpt, mark as `"content_match": false`
4. Log verification results

### Step 2.5: Report Progress

Tell the user:
```
PHASE 2 COMPLETE: Evidence Gathering
Agents dispatched: <N>
Total evidence items: <N>
Unique sources: <N>
Average credibility: <X.X>/10
URLs verified: <N>/<N> reachable
Languages: <N> Russian, <N> English sources

Phase 2 tokens: ~<N> input, ~<N> output
Phase 2 cost: ~$<X>
Running total: ~$<X>

Key preliminary findings:
- <finding 1>
- <finding 2>
- <finding 3>

Starting Phase 3: Adversarial Verification...
```

Update `token_usage.json`.

---

## PHASE 3: ADVERSARIAL VERIFICATION

**Goal:** Challenge the evidence through multi-perspective debate. Reduce overconfidence, catch contradictions, assign final confidence scores.

### Step 3.1: Prepare Evidence Summary

Create a condensed evidence brief from `all_evidence.md`:
- Group evidence items by sub-query/topic
- For each topic, list the top claims with their sources and credibility scores
- Include both supporting and contradicting evidence
- Keep under 4000 words to fit in agent context

Save as `<output_dir>/verification/evidence_brief.md`.

### Step 3.2: Launch Three Verification Agents (Parallel)

Use the **Task** tool to launch all three agents in a SINGLE message.

---

**OPTIMIST AGENT PROMPT:**

```
You are the Optimist Analyst. Your role is to find the STRONGEST case for the research findings.

## Evidence Brief
<paste evidence_brief.md content>

## Instructions

For each major claim in the evidence:
1. Identify the strongest supporting evidence
2. Look for additional supporting patterns across sources
3. Identify enabling factors and positive trends
4. Assess whether the supporting evidence is sufficient and credible
5. Note where the evidence is genuinely strong vs. where you are stretching

## Output Format

For each claim:

### Claim: <claim text>
**Support strength:** Strong / Moderate / Weak
**Best supporting evidence:**
- <source 1>: <why it supports>
- <source 2>: <why it supports>
**Enabling factors:** <trends, conditions that make this claim more likely true>
**Honest assessment:** <is the support genuine or am I reaching?>
```

---

**PESSIMIST AGENT PROMPT:**

```
You are the Pessimist Analyst. Your role is to FIND BUGS in the research findings. You are looking for contradictions, weaknesses, missing evidence, and overconfident claims.

CRITICAL INSTRUCTION: Your job is to "find bugs" in the evidence, NOT to "verify correctness." This framing reduces overconfidence by 15% (proven in multi-agent research).

## Evidence Brief
<paste evidence_brief.md content>

## Instructions

**STEP A: Search for counter-evidence (MANDATORY)**
Before analyzing the evidence brief, use WebSearch to actively search for CONTRADICTIONS:
- For the top 3 claims, search for negated queries (e.g., "risks of X", "X fails", "X problems", "критика X")
- Record any counter-evidence found with full source URLs

**STEP B: Analyze the evidence**
For each major claim in the evidence:
1. What CONTRADICTS this claim? Include counter-evidence from STEP A.
2. What is MISSING? What evidence would you expect to see but do not?
3. Is the claim OVERCONFIDENT? Does a single source claim get treated as fact?
4. Are there CIRCULAR CITATIONS? Do multiple sources trace back to the same original?
5. Is the evidence OUTDATED? Are claims based on data that may no longer be current?
6. What are the RISKS if this claim is wrong?

## Output Format

For each claim:

### Claim: <claim text>
**Vulnerability:** High / Medium / Low
**Counter-evidence found:**
- <source>: <what contradicts>
**Missing evidence:** <what is absent that should be present>
**Overconfidence risk:** <is this treated as more certain than warranted?>
**Circular citation risk:** <do sources trace to same origin?>
**Staleness risk:** <is the data potentially outdated?>
**Impact if wrong:** <consequences of acting on false claim>
```

---

**FACT-CHECKER AGENT PROMPT:**

```
You are the Fact-Checker. Your role is to cross-reference claims across sources and assign final confidence scores.

## Evidence Brief
<paste evidence_brief.md content>

## Instructions

For EACH factual claim (especially claims with specific numbers, dates, or statistics):

1. Count how many INDEPENDENT sources support this claim
2. Check if sources actually agree or merely appear to (same underlying data?)
3. Identify the PRIMARY source (original research/data) vs SECONDARY sources (reporting on it)
4. Check for temporal consistency -- are all sources from a similar time period?
5. Assign a confidence level:

| Level | Criteria |
|-------|----------|
| HIGH | 3+ independent sources agree, primary source identified, data < 2 years old |
| MEDIUM | 2 independent sources agree, OR 1 highly credible source (gov/academic), data < 4 years old |
| LOW | Single source only, OR sources disagree, OR data > 4 years old, OR claim is unverifiable |
| CONTESTED | Multiple credible sources directly contradict each other |

## Output Format

### Verified Claims

| # | Claim | Confidence | Sources | Primary Source | Notes |
|---|-------|-----------|---------|---------------|-------|
| 1 | <claim> | HIGH/MED/LOW/CONTESTED | <N> sources | <primary source URL or "none identified"> | <any caveats> |

### Contested Claims (detail)
For each CONTESTED claim:
- What source A says: <...>
- What source B says: <...>
- Likely explanation for disagreement: <...>
- Recommended interpretation: <...>

### Unverifiable Claims
Claims that cannot be verified with available evidence:
- <claim>: <why unverifiable>
```

---

### Step 3.3: Meta-Verification Synthesis

After all three verification agents return:

1. Read all three outputs
2. Create a unified verification report at `<output_dir>/verification/verification_report.md`:

For each claim, combine perspectives:

```markdown
### Claim: <text>
- **Optimist:** <support strength + summary>
- **Pessimist:** <vulnerability + key concern>
- **Fact-Checker:** <confidence level + source count>
- **FINAL CONFIDENCE:** <HIGH / MEDIUM / LOW / CONTESTED>
- **Reasoning:** <1-2 sentences synthesizing all three perspectives>
- **Action:** INCLUDE (use in report) / INCLUDE_WITH_CAVEAT / EXCLUDE / NEEDS_MORE_RESEARCH
```

Decision rules for FINAL CONFIDENCE:
- If Fact-Checker says HIGH and Pessimist vulnerability is Low: **HIGH**
- If Fact-Checker says HIGH but Pessimist found real counter-evidence: **MEDIUM** (downgrade)
- If Fact-Checker says MEDIUM and Optimist has strong support: **MEDIUM**
- If Fact-Checker says LOW or CONTESTED: **LOW** or **CONTESTED** (never upgrade)
- If Pessimist found circular citations: automatically downgrade one level

### Step 3.4: Report Progress

Tell the user:
```
PHASE 3 COMPLETE: Adversarial Verification
Claims analyzed: <N>
  HIGH confidence: <N>
  MEDIUM confidence: <N>
  LOW confidence: <N>
  CONTESTED: <N>
Claims excluded: <N>
Claims needing more research: <N>

Phase 3 tokens: ~<N> input, ~<N> output
Phase 3 cost: ~$<X>
Running total: ~$<X>

Key verification findings:
- <strongest claim with confidence>
- <most contested claim>
- <biggest gap found>

Starting Phase 4: Synthesis...
```

Update `token_usage.json`.

---

## PHASE 4: SYNTHESIS

**Goal:** Combine verified evidence into a coherent analytical narrative.

### Step 4.1: Structure the Report

Based on the verified claims and their confidence levels, determine the report structure. Use the research question to guide section organization.

Default structure (adapt based on query type):

```markdown
# <Research Title>

## Executive Summary
<3-5 paragraphs answering the original question directly>

## Key Findings
<numbered list of top findings with confidence indicators>

## Detailed Analysis

### <Topic Section 1>
<analysis with inline citations>

### <Topic Section 2>
<analysis with inline citations>

### <Topic Section N>
<analysis with inline citations>

## Contradictions and Open Questions
<contested claims, unresolved debates, gaps>

## Confidence Assessment
<summary table of confidence by section>

## Methodology
<brief description of research process>

## Sources
<numbered source list with URLs>
```

### Step 4.2: Write the Report

Write the full report following these rules:

**Citation format:** Every factual claim MUST have an inline citation: `[Source Name](URL)` or `[N]` with numbered references. Claims without citations are forbidden.

**Confidence indicators:** Use inline markers after claims:
- `[HIGH]` -- 3+ sources, verified
- `[MEDIUM]` -- 2 sources or 1 highly credible
- `[LOW]` -- single source, use hedging language ("reportedly", "according to one source")
- `[CONTESTED]` -- present both sides explicitly

**Language:** Write the report in the same language as the user's query. If query was in Russian, report in Russian. If English, report in English. If mixed, ask the user.

**Tone:** Analytical, evidence-based, no filler. State what the evidence shows, not what you think. Distinguish clearly between evidence and interpretation.

**Numbers:** Always cite the source of any statistic. Never round numbers from sources without noting it. Include the date of the data point.

**Contested claims:** Present all sides. Do not pick a winner unless the evidence strongly favors one side. Explain why sources disagree.

### Step 4.3: Save Report

Save the executive report to `<output_dir>/report.md`.

### Step 4.4: Write Longread (if depth = "standard" or "deep")

After the summary report, generate a detailed longread at `<output_dir>/report_longread.md`.

The longread differs from the summary:

1. **Full source excerpts:** Include 2-3 paragraph quotes from key sources, not just one-line claims. Show the reader the original text that supports each finding.

2. **Narrative structure per section:** Each STEP section becomes a mini-essay (800-1500 words) with:
   - Opening: why this factor matters for the specific business question
   - Evidence layer: data points with full citations and context
   - Adversarial debate inline: "Optimist perspective: [X]. However, Pessimist found: [Y]. Fact-Checker assessment: [Z]."
   - Cross-references: how this factor connects to other STEP dimensions
   - Implications: specific, actionable conclusions for the business

3. **Data tables:** Consolidate numbers into tables with source + year + confidence level. Example:
   ```
   | Metric | Value | Year | Source | Confidence |
   |--------|-------|------|--------|------------|
   ```

4. **Contradictions section expanded:** For each contested claim, present full arguments from both sides with source excerpts, not just a one-liner.

5. **Signals & monitoring:** For each major finding, specify what signal to watch, where to find it, and how often to check.

**Longread template:**

```markdown
# <Title> — Deep Analysis

## How to Read This Report
<brief guide: confidence markers, citation format, structure>

## <STEP Section 1: e.g., Social Factors>

### Context: Why This Matters
<1-2 paragraphs framing the section for the specific business question>

### Finding 1: <claim>
<2-3 paragraphs with full source excerpts, data tables, cross-references>

**The Debate:**
- Optimist: <what supports this>
- Pessimist: <what contradicts or weakens this>
- Verdict: <final assessment with confidence>

### Finding 2: <claim>
...

### Section Summary & Implications
<what this means for the business, specific actions>

## <STEP Section 2>
...

## Cross-Cutting Themes
<patterns that span multiple STEP dimensions>

## Strategic Implications
<integrated analysis: what the combined STEP picture means>

## Monitoring Dashboard
| Signal | Source | Frequency | Current Value | Threshold |
|--------|--------|-----------|---------------|-----------|

## Full Source Appendix
<all sources with extended metadata: URL, title, date, credibility, excerpt>
```

**Target length:** 4000-8000 words depending on depth mode.
**Language:** Same as report.md.

### Step 4.4: Report Progress

Tell the user:
```
PHASE 4 COMPLETE: Synthesis
Report length: <N> words
Sections: <N>
Inline citations: <N>
Confidence breakdown:
  HIGH claims: <N>
  MEDIUM claims: <N>
  LOW claims: <N>
  CONTESTED claims: <N>

Phase 4 tokens: ~<N> input, ~<N> output
Phase 4 cost: ~$<X>
Running total: ~$<X>

Starting Phase 5: Final Report...
```

Update `token_usage.json`.

---

## PHASE 5: FINAL REPORT

**Goal:** Finalize outputs and present results to the user.

### Step 5.1: Finalize Token Usage

Update `<output_dir>/token_usage.json` with final totals:

```json
{
  "research_query": "<query>",
  "started_at": "<ISO timestamp>",
  "completed_at": "<ISO timestamp>",
  "duration_minutes": "<N>",
  "phases": {
    "phase_1_planning": {
      "estimated_input_tokens": "<N>",
      "estimated_output_tokens": "<N>",
      "estimated_cost_usd": "<X.XX>"
    },
    "phase_2_evidence": {
      "agents": "<N>",
      "estimated_input_tokens": "<N>",
      "estimated_output_tokens": "<N>",
      "estimated_cost_usd": "<X.XX>"
    },
    "phase_3_verification": {
      "estimated_input_tokens": "<N>",
      "estimated_output_tokens": "<N>",
      "estimated_cost_usd": "<X.XX>"
    },
    "phase_4_synthesis": {
      "estimated_input_tokens": "<N>",
      "estimated_output_tokens": "<N>",
      "estimated_cost_usd": "<X.XX>"
    }
  },
  "cumulative": {
    "input_tokens": "<N>",
    "output_tokens": "<N>",
    "estimated_cost_usd": "<X.XX>",
    "model_used": "<haiku/sonnet/opus>"
  }
}
```

**Token estimation method:** Count words in all prompts and outputs, multiply by 1.3 for tokens (rough estimate for mixed EN/RU text). Apply model rates from the tracker.

### Step 5.2: Finalize Sources

Ensure `<output_dir>/sources.json` is complete and sorted by credibility score descending.

### Step 5.3: Output Directory Summary

Verify all output files exist:

```
<output_dir>/
  report.md              # Final research report
  research_plan.md       # Phase 1 query decomposition
  sources.json           # All sources with metadata
  token_usage.json       # Cost and token tracking
  evidence/
    all_evidence.md      # Combined evidence from all agents
    local_context.md     # Extracted context from user files (if any)
    local_kb.md          # Local knowledge base findings (if any)
  verification/
    evidence_brief.md    # Condensed evidence for verification
    verification_report.md # Combined verification results
```

### Step 5.4: Present Results to User

Show the user:

```
DEEP RESEARCH COMPLETE

Query: <query>
Duration: <N> minutes
Sources consulted: <N>
Evidence items: <N>
Verified claims: <N>

Estimated token usage: <N> tokens (~$<X.XX>)

Output directory: <output_dir>/
  - report.md (main report, <N> words)
  - sources.json (<N> sources)
  - token_usage.json (cost breakdown)

Top findings:
1. <finding 1> [HIGH]
2. <finding 2> [HIGH]
3. <finding 3> [MEDIUM]
```

Then display the Executive Summary section from report.md.

---

## TOKEN ESTIMATION RULES

Since Claude Code does not expose exact token counts, estimate as follows:

1. **Input tokens:** Count words in all prompts you construct (research plan, agent prompts, evidence briefs). Multiply by 1.3.
2. **Output tokens:** Count words in all generated text (plans, evidence, verification, report). Multiply by 1.3.
3. **Agent overhead:** Each Task agent call has ~500 tokens of system overhead. Add this per agent.
4. **WebSearch/WebFetch:** Each WebSearch returns ~200-500 tokens of snippets. Each WebFetch returns ~1000-5000 tokens of page content. Estimate based on number of searches and fetches.
5. **Cost calculation:** Use the model YOU are running on:
   - Opus: $15 / 1M input, $75 / 1M output
   - Sonnet: $3 / 1M input, $15 / 1M output
   - Haiku: $0.25 / 1M input, $1.25 / 1M output
   - Task agents (Haiku by default): $0.25 / 1M input, $1.25 / 1M output

6. **Running total:** After each phase, update cumulative totals and report to user.

---

## GRACEFUL DEGRADATION

Handle failures without stopping the research:

| Failure | Recovery |
|---------|----------|
| A Task agent times out | Continue with evidence from other agents. Note the gap in the report. |
| WebSearch returns no results | Try alternative query phrasings. If all fail, note as evidence gap. |
| WebFetch returns error (403/404/timeout) | Mark source as unverified. Use snippet from WebSearch results instead. |
| A verification agent fails | Continue with the other two. If Fact-Checker fails, the Pessimist findings serve as fallback confidence assessment. |
| All web search fails | Fall back to local knowledge base only. Clearly state in report that web evidence could not be gathered. |
| User interrupts mid-research | All intermediate files are saved. Research can be inspected in the output directory. |

**Never fail silently.** Always tell the user what went wrong and how you are recovering.

---

## SEARCH STRATEGY BY LANGUAGE

### Russian-language research (language = "ru" or "both")

1. **Primary:** Use WebSearch with Russian-language queries. WebSearch accesses multiple search engines including those with Russian coverage.
2. **Query construction:** Use natural Russian phrasing. Include domain-specific Russian terminology. For medical/legal topics, include both formal terms and colloquial equivalents.
3. **Source priorities for Russian research:**
   - Government: *.gov.ru, *.rosminzdrav.ru, *.rosstat.gov.ru -- credibility 9-10
   - Academic: *.elibrary.ru, cyberleninka.ru -- credibility 8-9
   - Major media: rbc.ru, kommersant.ru, vedomosti.ru, tass.ru -- credibility 7-8
   - Industry: specific industry portals -- credibility 6-7
   - Blogs/forums: habr.com, vc.ru -- credibility 4-5

### English-language research (language = "en" or "both")

1. **Primary:** Use WebSearch with English queries.
2. **Source priorities for English research:**
   - Academic: *.edu, arxiv.org, pubmed, scholar.google.com -- credibility 9-10
   - Government: *.gov, WHO, World Bank -- credibility 9-10
   - Major publications: Nature, Science, The Economist, FT, Bloomberg -- credibility 8-9
   - Industry research: McKinsey, Deloitte, Gartner, CB Insights -- credibility 7-8
   - Tech media: TechCrunch, Wired, Ars Technica -- credibility 6-7
   - Blogs/forums: Medium, Reddit, Hacker News -- credibility 3-5

### Bilingual research (language = "both")

1. Search Russian sources first for domestic data (regulations, market size, companies)
2. Search English sources for international context, methodologies, benchmarks
3. Cross-reference claims across languages -- a claim supported in both Russian and English sources gets a credibility bonus (+1)
4. Note language of each source in evidence items

---

## INTERACTION GUIDELINES

### Always Do

- Report progress after every phase -- the user must know what is happening
- Save intermediate files so research is inspectable and resumable
- Include inline citations for EVERY factual claim in the report
- Assign confidence scores to all claims
- Show estimated token usage and cost after each phase
- Use the Task tool for parallel agent dispatch -- never run agents sequentially
- Verify at least the top 10 source URLs are reachable
- Present contradictions honestly -- do not hide disagreements
- Ask the user before starting if the scope and depth are correct

### Never Do

- Never present a claim without a source citation
- Never assign HIGH confidence to a single-source claim
- Never skip the Pessimist agent -- it catches overconfidence
- Never merge sources that merely cite the same original study (flag as circular citation instead)
- Never generate fake URLs or sources -- if evidence is insufficient, say so
- Never translate Russian source quotes to English without marking them as translated
- Never round or modify statistics from sources -- quote exactly and cite
- Never continue to Phase 4 if all verification agents failed -- ask the user how to proceed

### Depth Calibration

| Depth | Sub-queries | Searches per query | Sources per query | Total evidence items |
|-------|------------|-------------------|------------------|---------------------|
| standard | 4-6 | 1-2 | 3-5 | 15-30 |
| deep | 6-8 | 2-3 | 5-10 | 30-60 |

---

## EXAMPLE USAGE

User says: "Research the current state of AI adoption in Russian healthcare. What is working, what is not, and who are the key players?"

**Phase 0:** Language=ru, depth=standard, output_dir=./research_output/ai_healthcare_russia_2026-03-18/

**Phase 1 produces these sub-queries:**

```
SQ-1: "внедрение ИИ в здравоохранении России 2025 2026"
  alt: "искусственный интеллект медицина Россия результаты"
  Language: ru
  Type: market overview

SQ-2: "AI healthcare Russia key companies startups"
  alt: "Russian healthtech AI companies funding"
  Language: en
  Type: competitive landscape

SQ-3: "проблемы внедрения ИИ в медицине России барьеры"
  alt: "почему ИИ не работает в российских клиниках"
  Language: ru
  Type: challenges (negation perspective)

SQ-4: "регулирование ИИ медицинские изделия Россия 2025"
  alt: "сертификация ИИ Росздравнадзор"
  Language: ru
  Type: regulation

SQ-5: "AI diagnostic imaging radiology Russia results accuracy"
  Language: both
  Type: specific use case with data
```

**Phase 2:** 3 agents dispatched in parallel. Agent 1 handles SQ-1 and SQ-4 (both Russian). Agent 2 handles SQ-2 and SQ-5 (English + both). Agent 3 handles SQ-3 (Russian, pessimist perspective).

**Phase 3:** Optimist finds strong government push signals. Pessimist finds implementation gaps and regulatory bottlenecks. Fact-checker confirms key statistics from multiple sources but flags outdated market size numbers.

**Phase 4:** Structured report with sections on Market Overview, Key Players, Regulatory Landscape, Implementation Challenges, and Outlook. Every claim cited. Contested market size estimates presented as a range.

**Phase 5:** Report delivered. 28 evidence items, 19 unique sources, average credibility 7.2/10.
