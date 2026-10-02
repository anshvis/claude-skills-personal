---
name: gold-star
description: Treat a designated piece of code as the gold standard — superior context — and hold or write other code to its pattern. Use when the user points at a function/file/module as "the gold star", "the reference", "the example to follow", or invokes /gold-star, and wants surrounding or new code reviewed against it (or written to match it). The user names the reference and the target scope; this skill extracts WHY the reference is good and applies those principles as the rubric.
---

# gold-star

One piece of code is the gold standard. Other code should be held to its pattern. This skill turns that reference into a rubric and applies it — as a review, a cleanup, or a template for new code.

The gold star is a **guide, not dogma**. The goal is to propagate the *principles* that make the reference good, not to xerox its surface shape into places it doesn't fit.

## Inputs

Resolve two things before starting.

1. **The gold star** — the reference code. A `file:line`, a symbol name, or "the thing we just discussed".
   - If the user names one, treat it as superior context: assume it represents the desired pattern even if other code in the repo disagrees with it.
   - If the user does **not** name one and says they're looking for one (e.g. "find a gold star for X", "is there a place that solves this properly?") — do not just ask them to supply it. Invoke `/investigate-code`-style root-cause search to locate a real candidate: identify the pattern/problem the target needs a reference for, then search the repo for an existing solved instance of it, evaluating each candidate the same way step 1 below would (why is it good, does it actually resolve the redundancy/problem cleanly, or is it just similar-looking duplication). Exclude the target scope itself and its own package/feature area from candidates — a feature can't be its own gold star. Present the strongest candidate(s) with file:line and the rationale before proceeding to step 2; if nothing in the repo qualifies, say so plainly rather than forcing a weak match.
   - If truly nothing is named and there's no ask to discover one either, ask.
2. **The target scope** — what to hold to it. A file, a feature, a directory, a diff, or "write X like this". Respect the scope literally; if the user said "JUST the foo module", do not wander into bar.

## Process

### 1. Anchor the gold star

Read the reference **in full**, plus enough of its callers and callees to know how it earns its keep. Then write down — for yourself — *why it is good*. Not what it does; why it's the standard. Name the pattern in a phrase the user would recognize.

Look for the load-bearing ideas, e.g.:
- What data flow / shape / layering does it commit to?
- What invariants does it hold (graceful fallbacks, single source of truth, no leaking of raw ids, batched IO, structured & reusable output)?
- What does it deliberately *not* do?

### 2. Derive a rubric

Turn each principle into a checkable criterion — something you can hold a piece of code against and get compliant / divergent / violation. Keep it to the few criteria that actually carry the reference's quality. A rubric of 4 sharp checks beats 15 vague ones.

### 3. Apply to the target

Walk the target scope. For each meaningful unit, grade it against the rubric and record a verdict with evidence (`file:line`):

- **Compliant** — already follows the principle.
- **Divergent (justified)** — differs, but for a context-appropriate reason. Say the reason. This is not a defect.
- **Violation** — diverges with no good reason, or reproduces the exact problem the gold star was designed to avoid. This is the work.

Pay special attention to code that *re-derives* what the gold star resolves once (the duplication/drift trap), and to data that the gold star already produces but the target throws away and recomputes worse.

### 4. Separate essence from incidentals

Before proposing any change, check it against the principle, not the syntax. Matching variable names, file layout, or call order without matching the *reason* is cargo-culting — call it out and skip it. A divergence that serves the gold star's intent better than the gold star's own shape would is a win, not a violation.

### 5. Act — but size the change to the risk

- **Clear, safe, in-scope violations** → fix them, matching the surrounding code's idiom.
- **Large, architectural, or contract-level changes** (wire-format changes, cross-package refactors, anything that ripples beyond the named scope) → do **not** silently undertake them. Present the finding with a concrete recommendation and the tradeoff, and let the user choose the depth before you touch it. A flagged/display-only feature rarely warrants a risky refactor; a core data path might.
- Never invent scope. "Make it clean" is not license to rewrite working code that merely differs in taste.

### 6. Verify

After any edit, run the cheapest sufficient check (type-check, the unit/db tests for the touched files). Report results plainly — if something fails, say so with the output.

## Output

Lead with a one-line verdict (does the target uphold the gold star?). Then a compact findings list: each item as `verdict — location — one line`. Then what you changed (if anything) and what you recommend the user decide. Quote the gold star's principle when explaining a violation so the standard is visible, not implied.

## Guardrails

- The gold star wins ties against other repo conventions — that's the point of designating it.
- Concise over exhaustive: report the findings that change a decision, not every stylistic nit.
- Don't over-engineer. The reference is a ceiling on quality, not a mandate to gold-plate everything around it.
