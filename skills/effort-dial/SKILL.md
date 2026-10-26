---
name: effort-dial
description: "Diagnose a task's intensity and deliberately set the effort level before doing the work — matching depth of thinking, exploration, planning, and verification to what the task actually warrants. Use at the start of a substantive request to avoid two failure modes: over-investing on mechanical/outlined work (slow, noisy, over-engineered) and under-investing on ambiguous or high-stakes work (shallow, wrong, missed blast radius). Trigger when a task is non-trivial and the right level of rigor is unclear, when the user explicitly asks to dial effort up or down, or when a task feels mismatched to the effort being spent on it."
---

# Effort Dial

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

Right-size effort to the task. Spend a few seconds diagnosing, pick a tier, then commit to that tier's behavior. Re-diagnose if the task turns out bigger or smaller than it first looked.

## Step 1 — Diagnose (read the signals)

Score the task on these axes. Higher = more effort warranted.

- **Specification** — Is the *what* and *how* already pinned down? Fully outlined ("change X to Y in file Z") → low. Vague intent ("make onboarding better") → high.
- **Scope** — One line / one file → low. Cross-cutting, many files, new module → high.
- **Novelty** — Mechanical pattern-following → low. Requires design, trade-off thinking, or a decision with no clear default → high.
- **Blast radius / reversibility** — Throwaway, local, trivially revertible → low. Shared code, migrations, customer-facing, hard to undo → high.
- **Confidence** — You already know exactly how → low. Real unknowns, need to read code or research → high.

Let the **highest** axis dominate, not the average. A one-line change to a shared migration is high-effort because blast radius is high, even though scope is tiny.

## Step 2 — Pick a tier

### 🟢 Quick — outlined, mechanical, low-stakes
Examples: rename, fix a typo, apply a clearly-specified edit, answer a direct question about known code.

- Just do it. No plan, no subagents, no preamble.
- Read only what you must touch.
- One verification pass appropriate to the change (does it compile / obvious correctness). Don't gold-plate.
- Prefer the smallest diff. Resist refactoring adjacent code.

### 🟡 Standard — typical feature work or a real bug fix with a known shape
Examples: implement a described feature, fix a bug with a clear repro, add tests, a focused refactor.

- Brief internal plan (don't necessarily surface it). Locate the right files with targeted search before editing.
- Follow existing patterns in the codebase; match surrounding style.
- Verify: run the relevant tests / type-check, or reason through the edge cases you changed.
- Use an `Explore` subagent if locating code spans many files; otherwise work directly.

### 🔴 Deep — project thinking, ambiguity, or high blast radius
Examples: architecture decisions, ambiguous "make this better", multi-file migrations, anything touching shared/DB/customer-facing surfaces, anything hard to reverse.

- **Resolve ambiguity first.** Settle facts by running something. Inside an `/ansh` run, a genuine preference call gets an agent default per [autonomy](../_shared/autonomy.md). Outside one, ask before building.
- **Plan before acting.** Inside an `/ansh` run the plan is `/ansh-plan`. Outside one, use plan mode (`EnterPlanMode`) when the approach itself is in question.
- **Explore broadly.** Fan out `Explore`/`Plan` subagents to map subsystems and find prior art before committing to a design.
- **Consider a Workflow** only if the user opted into multi-agent orchestration — otherwise propose it.
- **Verify hard.** Run tests, exercise the real path, check the blast radius (who else calls this?), consider failure modes. State plainly what was and wasn't verified.

## Step 3 — Announce the dial (lightly)

For Standard/Deep, lead with one short line so the user can correct the calibration:
> *Treating this as **Deep** (ambiguous + touches shared migrations) — I'll explore and bring a plan back before editing.*

For Quick, skip the announcement and just do it.

## Calibration guardrails

- **Honor explicit overrides.** "Just do the quick version" / "quick and dirty" → drop to Quick even if signals say higher. "Be thorough" / "audit this" → raise to Deep. The user's stated intent beats the rubric.
- **Don't sandbag the diagnosis to save effort.** The expensive error is under-investing on something irreversible. When torn between two tiers and blast radius is high, pick the higher one.
- **Don't perform effort.** Deep doesn't mean longer prose, more hedging, or ceremony — it means more *real* exploration, planning, and verification. Quick doesn't mean careless — it means no overhead.
- **Re-diagnose on surprise.** If a "Quick" edit reveals it touches shared code, stop and re-tier up. If a "Deep" task turns out fully specified, drop down.
- **Match the harness levers to the tier**, not the other way around: plan mode and subagent fan-out are for Deep; direct edits are for Quick. Reaching for heavy machinery on a one-liner is the over-investment failure mode.
