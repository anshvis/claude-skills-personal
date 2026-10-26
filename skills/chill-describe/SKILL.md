---
name: chill-describe
description: "Write commit messages and PR descriptions the way Ansh wants them. Commits stay short and per-change so individual changes can be reverted; PR descriptions are holistic (problem → fix → impact) in 2-3 paragraphs with bullets for enumerated items. MUST be applied before ANY `git commit`, `git commit --amend`, `gh pr create`, or `gh pr edit --body` runs — load this skill first, draft per its rules, then execute the git/gh command."
---

# chill-describe

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

Drafting style for commits and PR descriptions. Two different shapes — don't blur them together.

## When to apply (mandatory)

This skill is **always** in effect for commits and PR bodies in this repo. Before running any of the following, load this skill and draft the message per its rules — never freehand a commit subject or PR body:

- `git commit` / `git commit -m` / `git commit --amend`
- `gh pr create` (the `--body` value)
- `gh pr edit --body` / any update to an existing PR body
- Any wrapper skill that performs the above (`/ship`, `/land-and-deploy`, `/finalize-pr`, etc.) — apply chill-describe to the message that wrapper would generate before letting it commit/push.

If the user explicitly overrides the style for one message ("just use the default trailer this once"), honor that for that single message only; the skill resumes on the next commit/PR.

## Hard rule: no AI co-authoring, ever — and no emojis

Commits and PR bodies produced under this skill **must not** include any indication that an AI helped write the code or the message, and **must not** contain emojis anywhere. Strip the following from every commit message and every PR body before executing the git/gh command:

- `Co-Authored-By: Claude …` (or any `Co-Authored-By:` line referencing an AI model/tool)
- `🤖 Generated with [Claude Code](…)` or any "Generated with …" footer
- `Assisted-By:`, `Generated-By:`, or any equivalent trailer that names an AI/LLM/tool
- Inline phrases like "written by Claude", "AI-generated", "🤖", etc. in the body
- **Any emoji** — in the subject line, body, bullet markers, section headers, or anywhere else. This includes the obvious 🤖 / ✨ / 🚀 / ✅ / ⚠️ / 🐛 / 🎉, decorative bullets, gitmoji-style prefixes (`:sparkles:`, `:bug:`), and any other Unicode pictograph. Plain text only.

This applies even when the underlying harness/skill (e.g. the default Claude Code commit template, `/ship`, `/land-and-deploy`, `/finalize-pr`) would add these by default — remove them. Treat any AI co-author trailer or emoji as a defect in the draft and fix it before the commit/PR command runs.

The only exception is an explicit, in-the-moment user instruction to include it for one specific message ("add the Claude trailer on this one", "use the rocket emoji this time"). Default to off otherwise.

## Commits: short, frequent, per-change

One commit = one logical change. Many commits per PR is the goal, not a problem — it preserves the ability to revert a single change without unwinding the whole PR.

**Format:**
- One line. Imperative mood. Lowercase is fine.
- Describes *what* changed, not *why* (the why lives in the PR body).
- No body paragraphs unless something is genuinely surprising and won't fit on one line.
- No trailers, no co-author tags, no emoji, no "🤖 Generated with…" footer.
- Skip ticket prefixes unless the branch/team convention already uses them — match what's already in `git log`.

**Examples (good):**
```
add paycode column to shiftcell audit query
extract searchForShift SQL into shared builder
fix off-by-one in callout window calc
update snapshot for new migration
```

**Examples (bad — too vague or too heavy):**
```
fixes                                            ← what fix?
WIP                                              ← squash these out before pushing
Refactor the shift cell audit system to support  ← too long; split the work
  paycode lookups across callout and PTO paths
  and consolidate redundant SQL queries
```

**Splitting work into commits:**
- Move/rename in its own commit, separate from the edit that uses the new location.
- Generated files (migrations, snapshots, lockfiles) in their own commit when practical.
- Test additions can ride with the code they cover, OR sit in a follow-up commit — Ansh's preference is to commit the test alongside the change so a revert takes both.
- If a commit's diff spans more than ~3 unrelated concerns, split it.

## PR description: holistic, 2-3 paragraphs

Three things, in order: **the problem**, **the fix**, **the impact**. Total length 2-3 paragraphs. Use prose for the overarching framing; drop into bullets only when enumerating multiple discrete items (e.g., "what changed in code", "which surfaces are affected").

**Shape:**

```markdown
## Problem
<1 paragraph — prose. What was broken / missing / inconsistent, and why it mattered. Reference the trigger (incident, ticket, observation) if there is one.>

## Fix
<1 paragraph of framing, then a bulleted list of the actual changes if there are 3+ distinct ones.>

- <change 1 — one line, file or area in backticks if useful>
- <change 2>
- <change 3>

## Impact
<1 short paragraph OR a tight bulleted list. Who/what is affected, behavior change, perf/safety notes, follow-ups, anything reviewers need to know to merge confidently.>
```

**Rules of thumb:**
- Don't recap every commit verbatim — the commit list is right there in the PR. Summarize.
- "Problem" is prose because the framing is the whole point; bullets fragment it.
- "Fix" gets bullets when 3+ discrete changes; otherwise prose is fine.
- "Impact" gets bullets when listing affected surfaces / risks / follow-ups; otherwise one sentence.
- No test plan checklist unless the team's PR template requires one.
- No "🤖 Generated with Claude Code" footer.
- Link Linear tickets inline (`REV-538`) — don't add a separate "Tickets" section.

**Example (good):**

```markdown
## Problem
Two near-identical SQL queries in the shift cell audit path (callout vs.
shift_assignment) had drifted out of sync, so callouts were missing the
paycode column that assignments already exposed. Reviewers had flagged
the duplication twice without it being addressed.

## Fix
Consolidated both queries into a single shared builder, then added paycode
to the unified output.

- pulled `searchForShift` SQL into `RecordVersion/Repo.ts` as a single builder
- added `paycode` to the select list and threaded it through `ShiftCell`
- new `paycode-integration-meta-constraint` db test covers both shapes
- regenerated drizzle snapshot for the column add

## Impact
Callout rows now return paycode (previously `null` in the UI). No schema
change — paycode already existed on the underlying table. One new
migration for the snapshot bump; safe to deploy in any order relative to
the app rollout.
```

## Behavior when invoked

When this skill runs:

1. If asked to draft a **commit message**: look at the staged diff (or the specific change in question), write one short imperative line, output it directly. Don't add the co-author trailer.
2. If asked to draft a **PR description**: read the branch diff vs the base branch and the commit list, then produce Problem / Fix / Impact in the shape above.
3. If asked to **split work into commits**: propose a commit plan (one line per proposed commit) before staging anything.
4. Never add the "🤖 Generated with Claude Code" footer, `Co-Authored-By: Claude …` trailer, or any other AI-attribution line to either commits or PRs while this skill is active — see the "no AI co-authoring" hard rule above. If a wrapper skill or template tries to add one, strip it before the command executes.
