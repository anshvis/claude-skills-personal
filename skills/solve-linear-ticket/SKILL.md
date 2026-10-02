---
name: solve-linear-ticket
description: End-to-end workflow for taking a Linear ticket from URL/ID through plan, solve, end-to-end QA, multi-pass review, and ship. Accepts a Linear URL or ticket ID, fetches it via the linear-server MCP, proposes a branch name like `rev-554-indices-for-db-query` (tag + slug), confirms and creates it, asks clarifying questions, runs /plan-eng-review, implements the solution in plan mode, runs /qa to verify the fix end-to-end in the UI, runs three review passes (/review, /code-review, /security-review), and finishes with /ship while applying /chill-describe to every commit message and the PR body. Use when the user invokes `/solve-linear-ticket` or pastes a Linear URL/ID and asks to solve it end-to-end.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
  - Skill
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_comments
  - mcp__linear-server__list_issue_statuses
  - mcp__linear-server__get_team
  - mcp__linear-server__save_comment
  - mcp__linear-server__save_issue
---

# /solve-linear-ticket

End-to-end orchestration for a single Linear ticket. The skill is a thin conductor — each phase delegates to a dedicated skill. Your job is to keep the phases in order, never skip a STOP point, and apply `/chill-describe` to every git/gh write.

## Hard rules (always)

- `/chill-describe` is **mandatory** before any `git commit`, `git commit --amend`, `gh pr create`, or `gh pr edit --body`. Load it first, draft per its rules, then execute. This applies inside `/ship` too — if `/ship` would generate a default-templated commit or PR body, intercept and rewrite under `/chill-describe` rules before the command fires.
- No `Co-Authored-By: Claude` trailer. No "🤖 Generated with Claude Code" footer. No emojis anywhere in commits or PR bodies. Strip them from any draft before executing.
- Phases run in the order below. Do not collapse phases. Do not skip the clarifying-questions step even if the ticket "looks obvious" — the cost of one AskUserQuestion is far less than solving the wrong problem.
- Never push to `main`/`master`. Always work on a fresh branch created in Phase 1.
- **Linear status sync** is owned by this skill only at the "In Progress" transition (Phase 1.6). Downstream transitions (`In Review`, `Done`) are handled automatically by Linear's GitHub integration when the PR opens / merges — do not transition those manually.

## Phase 0 — Parse input

The user invokes this skill with either a Linear URL or a ticket ID (e.g. `REV-554`, `https://linear.app/team/issue/REV-554/...`).

1. Extract the ticket ID:
   - URL form: pull the `[A-Z]+-\d+` token from the path.
   - Bare ID form: use as-is, uppercase.
   - If nothing parseable, ask: "I couldn't find a ticket ID in your message — paste the Linear URL or the ID (e.g. `REV-554`)." then STOP.
2. Normalize to uppercase (`rev-554` → `REV-554`).

## Phase 1 — Fetch ticket and propose branch

1. Fetch the ticket:
   ```
   mcp__linear-server__get_issue with id=<TICKET_ID>
   ```
   Also list recent comments if useful context exists:
   ```
   mcp__linear-server__list_comments with issueId=<id>
   ```
2. Summarize the ticket in 2-3 sentences: what's broken/needed, who reported it (if known), any constraints in the description or comments.
3. Build the branch name: `<tag-lower>-<slug>`.
   - `tag-lower` = ticket ID lowercased (e.g. `rev-554`).
   - `slug` = 3-6 kebab-case words describing the work (e.g. `indices-for-db-query`). Pull from the ticket title, but rewrite to be specific and grep-able. Strip filler words ("fix", "the", "issue with"). All lowercase ASCII, hyphens only.
   - Examples: `rev-554-indices-for-db-query`, `rev-201-stripe-webhook-retry`, `vit-88-onboarding-empty-state`.
4. Confirm via AskUserQuestion:
   - A) Use proposed name `<tag>-<slug>` (recommended)
   - B) Edit the slug (user will type a replacement)
5. After confirmation, create the branch from the current default branch:
   ```bash
   _BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)
   git fetch origin "$_BASE" --quiet
   git checkout -b <branch-name> "origin/$_BASE"
   ```
   If the working tree is dirty, STOP and tell the user to commit or stash first. Do not stash on their behalf.
6. **Transition the Linear ticket to "In Progress"** (owned by this skill — see Hard rules):
   - Read the ticket's current `status` / `statusType` from the Phase 1.1 fetch.
   - If `statusType` is already `started` (e.g. status name `In Progress`), skip — log "Ticket already In Progress, skipping transition."
   - If `statusType` is `completed` or `canceled` (e.g. `Done`, `Cancelled`, `In Review`), STOP and ask the user via AskUserQuestion whether to re-open the ticket and continue, or abort. Do not silently flip a Done ticket back to In Progress.
   - Otherwise (`statusType` ∈ `triage` | `backlog` | `unstarted`), transition:
     ```
     mcp__linear-server__list_issue_statuses with teamId=<teamId from Phase 1.1 fetch>
     # Find the status where statusType="started" (typically named "In Progress").
     mcp__linear-server__save_issue with id=<TICKET_ID> and stateId=<that status id>
     ```
   - On failure (permission denied, status not found, MCP error): show the error, ask the user to transition manually in Linear, and continue with the rest of the skill. Do not block on this — the work can proceed without the status flip.

## Phase 2 — Clarifying questions

Read the ticket description and comments carefully. Identify ambiguity that would change the implementation:

- Scope edges ("does this also need to cover X?")
- Data model implications ("what does the column mean for existing rows?")
- User-visible behavior ("error toast vs silent retry?")
- Migration / deploy constraints ("safe to ship without downtime?")
- Edge cases the ticket doesn't address

Ask 1-4 clarifying questions via AskUserQuestion. If the ticket is genuinely fully specified, ask **one** sanity check: "I read the ticket as <one-line interpretation> — is that the scope?" with options A) Yes, that's it / B) Not quite, let me clarify.

After answers, write a short interpretation paragraph to the conversation so the user can correct course before /plan-eng-review consumes context on the wrong problem.

## Phase 3 — /plan-eng-review

Invoke `/plan-eng-review` via the Skill tool. Pass it the ticket summary, the clarified scope, and any constraints from Phase 2 so it has the context it needs.

`/plan-eng-review` runs in plan mode and produces a structured plan with review report. Wait for it to finish. When it asks AskUserQuestion gates, surface them — do not auto-decide.

After `/plan-eng-review` exits plan mode and the plan is approved, proceed.

## Phase 4 — Solve

Implement the plan from Phase 3. Follow these rules:

- Stay in scope. If you discover work the plan didn't cover, surface it as a question rather than silently expanding scope.
- Commit per logical change. One commit = one logical step. Many small commits beats one big one (matches `/chill-describe` rules).
- Before EACH `git commit`, draft the message per `/chill-describe` — one-line imperative, no co-author trailer, no emojis. Strip the default template if the harness adds one.
- Run the project's tests / typecheck / lint after each logical chunk that touches code. Don't ship red.
- If you hit a wall (failed approach 3x, ambiguous data model, destructive scope), STOP and surface options.

When the implementation is complete and all tests pass, move to Phase 5.

## Phase 5 — End-to-end QA (/qa)

Before any code review pass runs, verify the fix actually works in the running app. Reviewers spend cheaper attention if they can trust the change behaves correctly end-to-end.

1. Invoke `/qa` via the Skill tool. Brief it with:
   - The ticket ID and a one-line restatement of the bug / desired behavior.
   - The clarified scope from Phase 2 and the implementation summary from Phase 4.
   - The exact user-visible flow(s) to exercise (golden path + the specific edge case the ticket calls out).
2. Let `/qa` drive the app, exercise the flow, and report findings.
3. If `/qa` surfaces regressions or the original bug still reproduces, return to Phase 4: fix, recommit per `/chill-describe`, then re-run `/qa`. Do NOT advance to Phase 6 with a known failure.
4. If `/qa` is not viable for this change (pure backend / infra / migration with no user-visible surface, or environment can't be brought up), log that explicitly in the conversation — "QA skipped: <reason>" — and proceed. Never silently skip.

Only once `/qa` is clean (or explicitly waived with a reason) move to Phase 6.

## Phase 6 — Triple review

Run three review passes. Each runs sequentially in the current session so findings accumulate:

1. **`/review`** — the gstack pre-landing PR review. Catches scope drift, SQL safety, LLM trust boundaries, conditional side effects.
2. **`/code-review`** — correctness bugs and simplification opportunities at default effort. Pair with `--fix` if you want the findings applied automatically; otherwise apply them manually.
3. **`/security-review`** — built-in security review of the pending changes.

After each pass, address every actionable finding before starting the next pass. If a pass surfaces a finding the user should decide on (architectural, scope), surface it via AskUserQuestion and wait.

**Fresh-eyes pass (optional but recommended for risky changes):** if the diff touches auth, payments, data migrations, or anything destructive, spawn a fresh Agent (subagent_type: general-purpose or code-reviewer) with no prior session context and ask it to review the diff for the dimension that worries you most. Surface its findings.

## Phase 6.5 — Observability (/add-otel)

After review passes are clean and BEFORE shipping, instrument the change so it's debuggable in production. Reviewers have just confirmed the code is correct; now make it observable while the behavior is fresh.

1. Invoke `/add-otel` via the Skill tool, scoped to this branch's diff. It follows the observability-101 conventions (right signal per job, low-cardinality metric tags, canonical attribute names) and the repo's Effect-native idioms (`Effect.withSpan`/`annotateCurrentSpan`, `Effect.annotateLogs`, `Metric.counter/timer`).
2. Let it instrument new error paths, external calls, jobs/RPC endpoints, and slow operations, then verify (type-check + unit tests for touched packages).
3. Commit any instrumentation per `/chill-describe` (short imperative, no trailers/emoji) so it ships in this PR.
4. `/add-otel` hands SigNoz Terraform **alert** authoring to `/observability` — it will list the alert-worthy metrics. Surface that recommendation to the user; author the alert in this PR (invoke `/observability`) or note it as an immediate follow-up.
5. If the change genuinely has nothing to instrument (pure type/schema change, docs, test-only), log "Observability: nothing to instrument — <reason>" and proceed. Never silently skip.

Only once observability is added (or explicitly waived with a reason) move to Phase 7.

## Phase 7 — /ship with /chill-describe applied

Invoke `/ship`. Before letting `/ship` execute any `git commit` or `gh pr create`:

1. **Intercept the commit/PR draft.** `/ship` will assemble commit messages (squashing WIP commits) and a PR body. Read the draft.
2. **Load `/chill-describe`.** Apply its rules: short per-change commits, Problem/Fix/Impact PR body in 2-3 paragraphs, no co-author trailers, no emojis, no "🤖 Generated with…" footer.
3. **Link the Linear ticket inline** in the PR body (e.g. "Closes REV-554" or reference it in the Problem paragraph). Do not add a separate "Tickets" section.
4. **Rewrite the draft** to match `/chill-describe`, then let `/ship` execute the git/gh commands with the rewritten content.

If `/ship` insists on adding a default template / co-author trailer / emoji footer it cannot be talked out of, run the `git commit` / `gh pr create` manually with the `/chill-describe`-compliant message and skip the corresponding `/ship` step.

After the PR is created, post the PR URL back to the conversation. Optionally, drop a comment on the Linear ticket linking the PR via `mcp__linear-server__save_comment` — confirm with the user first.

## Phase 7.5 — Verify Linear transitioned to "In Review"

Linear's GitHub integration normally moves the ticket from `In Progress` → `In Review` automatically when a PR referencing the ticket opens. Verify it actually happened — webhooks occasionally lag or silently fail.

1. Wait briefly for the webhook (give it ~5-10 seconds after `gh pr create` returns).
2. Re-fetch the ticket:
   ```
   mcp__linear-server__get_issue with id=<TICKET_ID>
   ```
3. Read the `statusType`:
   - If `statusType` is `started` AND the status name indicates review (e.g. `In Review`): ✅ the integration fired. Log "Linear ticket transitioned to In Review."
   - If `statusType` is still `started` with the `In Progress` name: the webhook may still be in flight. Wait another 10 seconds, re-fetch once more. If still not transitioned, flip it manually:
     ```
     mcp__claude_ai_Linear__list_issue_statuses with team=<teamId>
     # Find the status where statusType="started" AND name matches "In Review" (or your team's equivalent).
     mcp__linear-server__save_issue with id=<TICKET_ID> and state=<that status id>
     ```
     Then tell the user: "GitHub→Linear integration didn't auto-transition the ticket within 20s — flipped it manually. Worth checking the Linear ↔ GitHub integration status if this keeps happening."
   - If `statusType` is something else entirely (`unstarted`, `backlog`, `canceled`): surface the unexpected state and ask the user how to proceed. Do not silently flip.

This verification step is owned by this skill because Phase 1.6 (the `In Progress` flip) is also owned here — symmetry of the contract.

## Phase 8 — Wrap up

One short summary, two sentences max:
- What shipped (PR URL).
- Anything left open (deferred items, follow-up tickets, manual QA the user should do).

Do not re-narrate the work. The diff and PR body already say what changed.

## Failure modes to watch for

- **Ticket not found / wrong ID:** Linear MCP returns an error. Show the error verbatim, ask the user to confirm the ID.
- **Branch already exists:** if `git checkout -b` fails because the branch exists, ask: continue on existing branch, or pick a different slug?
- **/plan-eng-review never exits plan mode:** likely a missing review report. Read its instructions and follow the EXIT PLAN MODE GATE — do not force ExitPlanMode without the gate passing.
- **`/ship` re-injects emojis or co-author trailer after your rewrite:** that's a hard violation of `/chill-describe`. Bypass `/ship` for the offending command and run `git commit` / `gh pr create` directly with the compliant text.
- **Multiple tickets in one branch:** this skill is single-ticket. If the user asks to bundle, tell them to invoke once per ticket or to use a different workflow.
- **Linear status transition fails:** the GitHub integration usually owns later transitions, but the Phase 1.6 "In Progress" flip is ours. If `save_issue` errors (auth, missing workflow state, team mismatch), surface the error verbatim, tell the user to flip it manually in Linear, and continue — never block the implementation on a status-sync failure.

## Completion status

End with one of:
- **DONE** — PR opened, all review passes clean, Linear linked.
- **DONE_WITH_CONCERNS** — PR opened but unresolved findings remain (list them).
- **BLOCKED** — could not proceed (state why and what was tried).
- **NEEDS_CONTEXT** — missing info from the user (state exactly what).
