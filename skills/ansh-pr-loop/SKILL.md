---
name: ansh-pr-loop
description: "Review-then-babysit PR driver. First runs /ansh-review as a triage (checks the diff against the linked Linear ticket, its parents and the TDD, sorts it into setup, logic or wiring and rates its blast radius); if that calls for manual review it comments on the PR and stops right there, before any other review or fix. Otherwise it runs the rest of the one-time review gate (/review-fresh, an independent review, /thermo-nuclear-code-quality-review), fixes blockers and majors (asking the user only about fixes that need a design decision), then auto-merges the user's own PRs only when /ansh-review clears them and every PR they depend on has merged (until then it waits). Then, every 5 minutes, combs the current PR for failing CI (each failure pulled from Buildkite, its log inspected, and fixed, retried or escalated), human review comments, and bot review comments (Cursor/vitalize-agent), fixes what it can, re-runs CI, and dismisses a stuck BOT review once its concerns are verifiably addressed. Never dismisses a human review. Loops until CI is green and no review is blocking, then auto-merges when cleared (or asks when merge=ask). Use when the user says \"/ansh-pr-loop\", \"babysit this PR\", \"watch this PR and get it mergeable\", or wants a standing PR-mergeable-driver instead of a one-shot /ansh-resolve pass."
---

# /ansh-pr-loop — recurring drive-to-green PR loop

**Runtime:** Read [ANSH runtime compatibility](../_shared/runtime.md) before starting.
Use its tool, model, path and review mappings for provider-specific examples below.

`/ansh-resolve` is one clean-up pass. This skill first runs a one-time **review gate**
that starts with `/ansh-review` (plan alignment, kind and blast radius). If it calls for manual
review, the PR goes to a person straight away and nothing else runs. Otherwise the gate adds
`/review-fresh`, an independent review and `/thermo-nuclear-code-quality-review`, then runs that
clean-up pass every 5 minutes,
self-pacing until the PR is actually mergeable. On the user's own PRs it then auto-merges by
default (the user's standing choice: fix the majors, then auto-merge), unless the user asked
for `merge=ask` for this PR, `/ansh-review` says it needs manual review, or a PR it depends on
hasn't merged. It never merges someone else's PR without an explicit yes. Stacked branches follow
[stacking](../_shared/stacking.md).

**Relationship to `/ansh-resolve`:** don't reimplement the comb/triage/dispatch/close logic here.
Each iteration's body is literally `/ansh-resolve`'s Phase 1–4, invoked via the Skill tool against
the PR. This skill only adds: the review gate and the merge call, the recurring cadence, the
per-failure Buildkite CI triage (Step 1.5), the stuck-bot-review escalation
(dismiss-after-verified-fix), the loop's stop condition, and the merge step.

**Worktree hygiene.** Same rule as `/ansh-resolve` — operate from the worktree that already
tracks this PR's branch. Don't drive a PR loop from an unrelated branch's worktree.
(See memory `feedback-worktree-and-session-per-task`.)

## Step 0 — identify the PR, once

If the user didn't name a PR number, resolve it from the current branch: `gh pr view --json
number,url,headRefName`. Confirm the number back to the user in your first status line so it's
unambiguous which PR is being babysat for the rest of the loop.

## Step 0.5 — review gate, once (before any babysitting)

Skip this step only on a wakeup fire whose prompt already carries `reviewed merge=<auto|ask>`
(see Step 5). Every fresh invocation runs it, but reuses a recorded gate when one still applies
(step 0).

**Own PR or not.** Compare the PR author with the user's login:
`gh pr view <n> --json author -q .author.login` against `gh api user -q .login`. Recording and
reusing the gate (steps 0 and 2b) only happen on the user's own PRs. On someone else's PR, skip
both: always run the reviews, and never post the gate comment.

**Your comments are your review.** On the user's own PR, check whether the user has already
reviewed it: an inline comment that starts a thread, a review with a body, or an approval, all by
the user's login. Replies inside a thread don't count, because the loop posts those as the user
too. Find them with `gh api repos/{owner}/{repo}/pulls/<n>/comments` (`in_reply_to_id == null`)
and `.../pulls/<n>/reviews`. If any exist, the manual review has happened:
- Never post, or post again, a "needs manual review" merge call or an `ansh-review (triage)`
  gate. If one is already on the PR, edit its headline to `**Manual review complete**` with the
  date of the user's last review comment.
- Don't stop with STOPPED_FOR_HUMAN, send "needs your review", or ask the user in chat. Run the
  full gate and the loop. **From here the rest is the agent's job.** The user's comments are the
  review findings, and the agent resolves every one of them itself in Step 1:
  - A question ("what model is this?", "why 4?"): research it (the ticket, its parents, the TDD,
    the plan files, the code), answer it on the thread in plain language, and change the code
    when the honest answer shows a problem.
  - A request or a criticism ("this seems like slop", "make sure the logs capture what we
    need"): make the change, verify it, push, and reply with the sha and what changed.
  - A direction or scope question ("we haven't decided a model", "what ADT data will we pull
    in?"): make the call yourself. Pick the option that best fits the ticket, the TDD and the
    plan, usually the smaller and more reversible one, and implement it. Say on the thread what
    you decided and why, so the user can push back with another comment. When a comment widens
    the scope beyond this PR, do this PR's share and open a Linear ticket for the rest, and
    link it in the reply.
- These rules override the "ask the user" steps elsewhere in this skill for a reviewed PR: the
  human-blocker flag, step 3's "ask the user that specific question", and the scope-change STOP
  points all become "decide, do it, explain it on the PR".
- Re-triage still runs, but a `manual-review` call on a reviewed PR is ignored. The user's
  next comments are the review of whatever the agent changed.

Once every one of the user's comments has a reply and the code changes are pushed and green, the
PR auto-merges like any `auto` PR.

0. **Reuse a recorded gate (own PRs only).** Look for an earlier gate comment on the PR:
   `gh api repos/{owner}/{repo}/issues/<n>/comments` and pick the newest comment whose body
   starts with `<!-- ansh-pr-loop:review-gate head=<sha> -->`. If there is one, fetch and list
   the PR's own commits since that `<sha>`:
   `git log --no-merges --format=%H <sha>..origin/<head-branch> --not origin/<base-branch> origin/main`.
   The `--not` part matters: merging `main` or the base in brings in other people's commits,
   and those are not changes to this PR.
   - **Empty** (nothing new, or only merges of `main`/the base branch): the PR's own code is
     unchanged, so the gate still applies. Skip all three reviews. Read the
     severity-ranked list back from the comment and go straight to step 3. Say "reusing
     review gate from <sha>" in your status line. Exception: if the gate's header doesn't
     list `thermo-nuclear` (it was recorded before that review joined the gate), run only
     `/thermo-nuclear-code-quality-review` now, merge its findings into the recorded list,
     and edit the comment (header and rows) rather than re-running the other two. Same for
     `ansh-review`: if the header doesn't list it, run only `/ansh-review` (step 1b) and merge
     its rows and merge call in.
   - **The recorded gate is `ansh-review (triage)`** (it called manual review): if the user has
     reviewed the PR since ("Your comments are your review" above) or cleared the call, run the
     full gate now and replace the triage-only comment. Otherwise, unless the code or plan
     changed, stop again exactly as in step 1a. Don't run the other reviews.
   - **Plan changed since the gate.** Even with no new commits, re-run only `/ansh-review` if
     the linked ticket, a parent ticket or the TDD was edited after the gate's date (compare
     each one's `updatedAt`). The code may be unchanged while the target moved.
   - **Any commit listed:** the PR's code changed. Run the reviews again (step 1) and record
     a new gate comment (step 2b).
   - **`<sha>` is not in the branch's history** (the history was rewritten): treat it as
     changed and run the reviews again.

1. **Pin one head for every reviewer.** `git fetch origin`, then merge `origin/<base>` in if
   the branch is behind its base (see [stacking](../_shared/stacking.md)). Push that merge, then
   record the head SHA and give the same SHA to every review. Never rebase or force-push a
   pushed branch to suit a reviewer.

   **Every review runs in its own subagent, never in this agent.** That covers the `/ansh-review`
   triage, each `/review-fresh` lens, the independent review and
   `/thermo-nuclear-code-quality-review`. Do not load a review skill with the Skill tool here and
   do its work in this conversation. Spawn one subagent per review (the runtime guide's
   delegation: a fresh `Agent`, or `delegate_task` for another provider). Tell it the pinned SHA,
   the read-only checkout or diff, which skill to read and apply, the output format, and that it
   must not edit, commit, push or post. This agent only briefs the reviewers, reads their reports
   and merges them (step 2). It does not review the code itself, so its view of the PR stays out of
   the findings. Posting to the PR (the merge call, the gate comment) stays with this agent, using
   what the subagent reported. If the host cannot spawn a subagent, report that review as
   unavailable instead of running it here.

   1a. **Triage with `/ansh-review` first (step 1b), alone.** It is the cheap pass, and it decides
   whether the rest of the gate is worth running.
   - **`manual-review`, and the user has already reviewed the PR**: the call is cleared. Follow
     "Your comments are your review" above and carry on as `auto`.
   - **`manual-review`, not yet reviewed**: stop here. Don't run the other three reviews, don't fix anything and
     don't start the babysitting loop; a person is going to look, and automated fixes to a PR
     whose direction isn't settled are wasted or wrong. Make sure the merge-call comment is on the
     PR, record a gate comment with just the triage (step 2b, header `ansh-review (triage)`), then
     `PushNotification` "PR #<n> needs your review: <reason>", unwatch the PR, and end with
     **STOPPED_FOR_HUMAN**. A later run (after the user replies, re-scopes, or says "go ahead")
     starts again from step 0; "go ahead" for this PR counts as clearing the call.
   - **`auto`**: run the other three review lenses, in parallel when supported, otherwise
     serially. If `/ansh-review` listed open dependencies, carry on too: the PR can still be
     reviewed and driven to green, but its merge waits (step 4).

   **Cornerstone PRs.** A cornerstone PR is a high-blast-radius PR that sets up others: later PRs
   in the stack or milestone build on what it introduces, so a wrong call there is copied into
   every PR above it. Typical cornerstones change a shared contract or type with callers, add a
   migration or trigger on a hot table, put a new lock or write on a hot path, or add the flag,
   bootstrap or mode that the rest of the work switches on. Cornerstones are the PRs the user must
   review personally. Decide from the diff and the plan, never from CI: green CI says the code
   runs, not that the foundation is right. A PR with a high blast radius that nothing builds on
   (an infra pipeline, a dashboard) still gets `manual-review`, but it is not a cornerstone. A PR
   that others build on but that nothing reaches yet (a new table with no readers) is a
   foundation, and only needs a skim of its shape. Say `Cornerstone: yes` or `no`, with the
   reason, in the merge-call comment and in the "needs your review" notification. When the user
   asks which PRs need their review, list the cornerstones first, then the others with what each
   one actually needs (a skim, one specific sign-off, or a teammate approval).

   The other three lenses (only after an `auto` triage):
   - `/review-fresh`, in a subagent that reads `../review-fresh/SKILL.md`, with the PR
     title/one-line intent as its argument. Its capture rebases, so the subagent runs it against a
     detached temporary worktree at the pinned SHA, diffing against `origin/<base>`, never against
     the PR branch itself. Its three lenses are each their own subagent too, as that skill already
     requires.
   - An independent review via the runtime guide, with the PR's intent and its riskiest
     areas as done-criteria/watch-outs. Record actual reviewer identity and independence;
     label its findings `independent` rather than assuming Codex is a different model.
   - `/thermo-nuclear-code-quality-review`: the strict maintainability review (abstraction
     quality, missed "code judo" simplifications, spaghetti growth, files pushed past 1k lines,
     wrong-layer or duplicated helpers). That skill sets `disable-model-invocation`, so the Skill
     tool can't load it: run it as a background `Agent` whose prompt tells it to read
     `../thermo-nuclear-code-quality-review/SKILL.md` and apply it to
     `git diff origin/<base>...HEAD`, read-only (no edits, commits or pushes), returning each
     finding as presumptive-blocker / major / minor with `path:line`.

   1b. **`/ansh-review` in PR mode: is it what we planned, and what breaks if it's wrong?** The
   other three reviews judge the code on its own terms. Spawn a subagent that reads
   `../ansh-review/SKILL.md` and runs it with the PR number and the pinned SHA, returning its
   verdict block and the merge-call text rather than posting them. Its triage (Phases 2 and 3)
   finds the linked tickets, their parents and the TDD, rates the plan gap, sorts the PR into
   setup, logic or wiring, rates the blast radius and makes the merge call (`auto` or
   `manual-review`); this agent posts that merge call on the PR. On `manual-review` it returns
   `TRIAGED` and stops (step 1a). On `auto`, skip its
   independent pass (Phase 4), because the independent review in step 1a covers it. Map its output
   into the gate:
   - Its BLOCKERS → blocker, with source `ansh-review`.
   - A small plan gap, or a mixed-kind PR → minor. (A large gap never gets here: it means
     `manual-review`, which stopped the gate in step 1a.)
   - A plan that looks stale, or extra scope: ask the user before splitting the PR or editing
     the ticket or TDD. This is the scope-change STOP point.
   - No linked ticket or TDD: `/ansh-review` says so; note it in the status line and go on.
2. **Merge findings into one severity-ranked list.** Collapse duplicates (keep the strictest
   severity, note both sources). Map onto one scale:
   - **blocker**: review-fresh `blocker`, independent-review critical finding, or a thermo-nuclear presumptive blocker
     (its "Approval Bar" list: a visible code-judo move left on the table, a file pushed past
     1k lines, ad-hoc branching tangling a shared flow, scattered feature checks, an
     unnecessary wrapper/cast contract, a duplicated helper or wrong layer)
   - **major**: review-fresh `major`, or another structural thermo-nuclear finding
   - **minor**: review-fresh `minor`, independent-review advisory finding, or a thermo-nuclear legibility note

   2b. **Record the gate on the PR (own PRs only).** Post one top-level PR comment with the
   merged list so a later run can reuse it (step 0). If an older gate comment exists, edit
   that one (`gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id>`) instead of adding
   another. Shape:

   ```markdown
   <!-- ansh-pr-loop:review-gate head=<full head sha> -->
   **Review gate** for `<short sha>` (ansh-review + review-fresh + independent + thermo-nuclear, <YYYY-MM-DD>; or `ansh-review (triage)` alone when it called manual review)

   Checked against: <FND-1234 (closes), parent FND-1200, TDD: <title + link> | no linked ticket>
   Kind: <setup | logic | wiring>. Blast radius: <low | medium | high>. Merge call: <auto | manual-review>, <reason>

   Worst severity: <blocker | major | minor | none>

   | Severity | Source | Finding | Where |
   |---|---|---|---|
   | major | review-fresh | <one line: what is wrong and the failure it causes> | `path:line` |
   | minor | independent | ... | ... |
   | major | ansh-review | <criterion or TDD section, and how the diff misses or contradicts it> | `path:line` or ticket key |

   <"Clean: no findings." when the list is empty>
   ```

   Use the PR's own voice: no AI attribution, no emoji. Write findings in plain language,
   one line each, and do not paste the reviewer's raw output. The `head=` sha is the commit that
   was reviewed. After step 3 pushes the gate's own fixes, edit the comment: mark each fixed
   row `fixed in <sha>`, and move `head=` to the pushed fix commit. Those fixes were verified
   against the gate's findings, so they must not trigger a full re-review on the next run.
   Any later non-merge commit (a loop fix or a new change) does trigger one.
3. **Fix blockers and majors before babysitting.** Dispatch each blocker and major through
   `/ansh-task` (or `/ansh-debug` for a real bug) exactly as `/ansh-resolve` would, verify
   (tests, type-check, lint), and commit per `/chill-describe`. Fix minors only when they are
   cheap and inside the files you are already changing. A major that cannot be fixed without a
   product or design decision (it changes behaviour, a contract, or what the author asked for)
   is not fixed silently: ask the user that specific question, then fix per the answer.
   Plan gaps follow the same rule. Fix a missing criterion or a TDD contradiction when the
   ticket and TDD make the right answer clear and it fits in this PR. If closing the gap is a
   new piece of work (more than this PR's share), or it needs the scope call from step 1b, leave
   it for the user. After fixing, re-run `/ansh-review`'s triage so its merge call reflects the fixed
   code. If the fixes flipped it to `manual-review` (for example a fix had to touch a shared
   contract), push what is verified and stop exactly as in step 1a.
4. **Merge mode is `merge=auto` by default. Do not ask the merge-mode question.** The user's
   standing choice (2026-10-19) is "fix the majors, then auto-merge". Once the gate's blockers
   and majors are fixed and pushed, the loop squash-merges on convergence without asking. Say
   in the status line what was fixed and what (minors only) is left.
   - Use `merge=ask` only when the user says so for this PR or invocation (for example
     `/ansh-pr-loop <n> merge=ask`, or "ask me before merging").
   - A blocker or major that is still open (one left for a user decision, or a fix that failed
     verification) holds the merge. Keep looping on CI, but do not merge until it is fixed or
     the user explicitly waives it.
   - On someone else's PR, default to `merge=ask`. The standing auto-merge covers the user's
     own PRs only.
   - **`/ansh-review`'s merge call overrides `merge=auto`.** A `manual-review` call stops the gate
     before the other reviews run (step 1a), so the loop never starts on that PR. If a later
     re-triage flips to `manual-review` mid-loop, stop at once the same way (Step 4, "Manual
     review called").
   - **Dependencies hold the merge.** Read `Depends on #<n>` from the PR body and check the PR's
     base. Do not merge while any dependency is open, and wait while any dependency is in manual
     review. Once a dependency merges, retarget and merge up the stack (stacking, "When a
     dependency merges"), then let CI run on the new head.
   - **A parent in manual review only delays its children.** A child PR keeps its own merge call:
     a parent's `manual-review` never makes the child manual-review, and the child's loop does not
     stop. Drive the child to green and leave it ready to merge. Post (or edit) one comment on the
     child, in the PR's own voice:

     ```markdown
     <!-- ansh-pr-loop:waiting-on -->
     Waiting on #<parent> (<needs manual review | open>). This PR merges automatically once
     #<parent> merges and CI passes on the merged-up head.
     ```

     Watch the parent as well as the child (on T3, `watch_pull_request` for both). Once the user
     has reviewed the parent and it merges, retarget and merge up the child, edit the comment to
     say #<parent> merged, and auto-merge the child when it converges. The child needs no review
     request of its own unless its own triage called `manual-review`.

   Carry the mode in every later wakeup prompt (Step 5), so the choice survives across fires.

5. **Push** the gate's fix commits (an ordinary push, never a force-push), then start the loop
   at Step 1.

## Step 1 — each iteration's body

Invoke `/ansh-resolve` (via the Skill tool) scoped to this PR number. Let it gather, triage,
dispatch fixes through `/ansh-task`/`/ansh-debug`, re-run checks, and close threads exactly as
that skill defines. Do not duplicate its GraphQL/`gh`/`bk` recipes here — read
`../ansh-resolve/SKILL.md` for the mechanics if you need a reminder.

Then make sure **every human comment has an answer from us**, not just the threads
`/ansh-resolve` acted on. That means inline threads, review bodies (including ones on an
`APPROVED` or `COMMENTED` review), and top-level PR conversation comments
(`gh api repos/{owner}/{repo}/issues/<n>/comments`). For each human comment with no later reply
from us:

- **Question, or "I don't understand X".** Answer it in plain language on the same thread or as a
  reply comment that quotes it. If it points at a real problem, fix it first and say what changed
  (commit sha).
- **Request or nit.** Reply with what changed (commit sha), or why it was declined.
- **Praise or FYI with nothing to answer.** No reply needed.

Answer in the PR's own voice: no AI attribution, no emoji. Skip comments that were already
answered, so a re-fire never double-posts. Never resolve a human's thread just because you
replied. Resolve it only once the change is done, per `/ansh-resolve`. If answering needs a
judgment call only the user can make, set the human-blocker flag below instead of guessing.

Then run Step 1.4 for `vitalize-agent`'s review and Step 1.5 for every failing CI check. On top of `/ansh-resolve`'s own output, track two
extra things per iteration:

- **Stuck-bot counter** — for each bot reviewer (Cursor `clearpath-it`, `vitalize-agent[bot]`,
  or similar) currently at `CHANGES_REQUESTED`, note whether this iteration's fixes genuinely
  addressed every finding that review enumerated (per `/ansh-resolve`'s Phase 4 disposition
  invariant — fixed+pushed, or a settled wontfix reply). If yes, but the bot hasn't cleared its
  own review to re-review the new commits, increment that bot's stuck-counter.
- **Human-blocker flag** — if a *human* reviewer's `CHANGES_REQUESTED` is not resolvable by a
  mechanical fix this iteration (needs a judgment call, disagreement, or scope question), set the
  human-blocker flag. This is a STOP condition (Step 3), not something to loop past silently.

## Step 1.4 — vitalize-agent: its review is a CI gate

`vitalize-agent[bot]` reviews each push late, often up to 30 minutes after it, and its findings
have to be fixed before CI counts as passing. Treat its review like a required check, not like an
optional bot comment. Its review lands after the loop has looked at a push, so a pass that only
reads the PR when CI finishes will miss it. Do this every iteration and after every push:

1. **Find its review of the head commit.** List its reviews and inline comments
   (`gh api repos/{owner}/{repo}/pulls/<n>/reviews` and `.../pulls/<n>/comments`, filtered to
   `vitalize-agent[bot]`). Its review covers the head only if its `commit_id` equals `headRefOid`.
   Its top-level PR comments count too.
2. **No review of the head yet:** the PR is not converged. Arm a one-off recheck 30 minutes
   after the push, on top of the PR watcher, because the watcher can miss the bot's review: a
   `ScheduleWakeup` with `delaySeconds: 1800` where the host has it, otherwise the host's
   one-shot scheduler (on T3, `schedule_task` bound to this thread). Don't merge in the meantime.
3. **It left findings or requested changes:** fix every finding the same turn, as
   `/ansh-resolve` would (fix, verify, commit, push), and reply on each thread with the fix
   commit. Dismiss a finding only when it is stale (the code it quotes is gone) or wrong, and
   say why in the reply. Then go back to step 2 for the new head: the bot reviews the new push
   too.
4. **It approved the head with no open findings:** this gate has passed.

Step 3's convergence and Step 4's merge both need this gate to have passed on the current head.

**Auto-merge must never outrun this gate.** GitHub's `--auto` waits for required checks only, and
`vitalize-agent` is not one, so its review often lands just after CI goes green. So:
- Arm `gh pr merge --squash --auto` only after `vitalize-agent` has passed the current head.
- Before pushing a new commit to a PR that already has auto-merge on, disable it with
  `gh pr merge <n> --disable-auto`. Re-arm it once the bot has passed the new head.

## Step 1.5 — CI failures: inspect every one in Buildkite

Every failing check gets its own Buildkite investigation. Never treat "CI is red" as one item,
never guess the cause from the check name, and never push an empty commit to "see if it passes".
Do this every iteration, after `/ansh-resolve` and before Step 2. (`/ansh-resolve` mentions
`bk`; the `bk` CLI is often not installed here, so use the vitalize MCP Buildkite tools below,
always with `org_slug: "vitalize"`. Use `bk` only as a fallback when it is on `PATH`. `gh run
view` cannot read Buildkite logs.)

1. **List the checks on the current head.**
   `gh pr checks <n> --json name,state,bucket,link` plus `gh pr view <n> --json headRefOid`.
   Every `buildkite/*` check links to `https://buildkite.com/vitalize/<pipeline>/builds/<number>`;
   parse the pipeline slug and build number from that link.
2. **Make sure the build is for the head commit.** Call Buildkite capability `buildkite_get_build` (or
   `buildkite_list_builds` with `branch`) and compare its `commit` with `headRefOid`. A build for
   an older commit, or one `canceled` because a newer push superseded it, is stale. Ignore it and
   look at the head's build. Only a failure on the head counts.
3. **Pull the failure for each failed build.** Start with
   Buildkite capability `buildkite_get_failed_job_logs` with the pipeline slug and build number. It returns the
   failed jobs, the build annotations and each job's log tail in one call.
   - Trust the annotation's own count (e.g. "5365 tests, 1 failures") over shard noise in the logs.
   - If the tail does not show the cause, re-run it with a runner-specific `grep_pattern`:
     `\(fail\)|✗` for bun/vitest/jest, `error TS\d+` for tsc, `deadlock|constraint|violates` for
     DB tests, `Error:|FAILED` for lint/format steps. Avoid `error|fail`, which matches wrapper noise.
   - Go deeper with `buildkite_search_logs` (needs the job's UUID) or `buildkite_get_job_logs`.
     For Test Engine suites, `buildkite_get_build_test_engine_runs` and then
     `buildkite_get_failed_executions` with `include_failure_expanded: true` give the full
     assertion and stack trace.
   - Write down, per failure: pipeline, build number, job (step label), the exact error line(s),
     and the file/test it names. That is the record every later decision cites.
4. **Classify each failure, from the evidence, never from the name.**
   - **Code failure.** The error names code, a test or a type this PR touches, or the same step
     passes on `main` and fails here. Reproduce it locally with the same command the step runs
     (read it from the job log or `.buildkite/**/pipeline.yml`), fix it through `/ansh-task` (or
     `/ansh-debug` if the cause is not obvious), confirm the local run is green, commit per
     `/chill-describe` and push. Not fixed until the same step is green on the new head's build.
   - **Flaky / infra.** The log shows an agent lost, a timeout with no test failure, a registry
     or network error (e.g. a CodeArtifact 401, `ECONNRESET`), an OOM kill, or a test that has
     nothing to do with this diff and passes on a retry or on `main`. Retry that job with
     Buildkite capability `buildkite_retry_job` (job UUID from the failed-job logs; use
     `buildkite_rebuild_build` only when the whole build died before running jobs). **At most one
     retry per job per head commit.** If the retried job fails the same way, it is no longer
     "flaky": treat it as a code failure, or STOP and report it if it is truly outside the PR.
   - **Expected / known.** A failure that memory or the repo documents as expected for this
     branch (e.g. playwright on the cba base) is noted in the status line, not retried or looped on.
   - **Unclear.** If the log does not support either reading, run one deeper search (step 3)
     before deciding. If it is still unclear, report it with the evidence. Do not retry blindly.
5. **Pending checks.** If a head build is still `running`/`scheduled`, arm a `Monitor` on it
   (Step 5) instead of waiting out the full 5 minutes. Check `TaskList` first so the same build is
   not watched twice.
6. **Report CI per check in each status line**: `<check>: passed | running | failed (<step>:
   <one-line cause>) -> fixed in <sha> | retried | known | escalated`. A failure is only gone when
   the head's build for that check has passed.

## Step 2 — stuck-bot escalation: dismiss, never for humans

**Never dismiss a human review, under any condition.** A human `CHANGES_REQUESTED` is either
cleared by the human re-reviewing, or it's a Step 3 STOP for the user to resolve directly — this
skill does not have standing to override a person's review.

A **bot** review (Cursor bugbot, `vitalize-agent[bot]`, or similar) is fair game to dismiss, but
only when ALL of these hold:
1. Every finding in that bot's review has a Phase-4 disposition (fixed+pushed, or wontfix-replied)
   — verified, not assumed.
2. The fix has been pushed for at least one full iteration already (i.e. this is the *second*
   consecutive iteration this bot has stayed `CHANGES_REQUESTED` since the fix landed) — bots
   often just need one more scheduled run; don't dismiss on the same cycle the fix went out.
3. The stuck-counter for that bot is ≥2.

When all three hold, dismiss it:

```bash
gh api graphql -f query='query { repository(owner:"<owner>",name:"<repo>") {
  pullRequest(number:<n>) { reviews(last:20) { nodes { id author{login} state } } } } }'
# find the bot review's node id, then:
gh api graphql -f query='mutation { dismissPullRequestReview(input: {
  pullRequestReviewId: "<id>",
  message: "Findings addressed in <commit shas> — re-review pending, dismissing stale block."
}) { pullRequestReview { state } } }'
```

Post one PR comment naming which review was dismissed, why (commits that addressed it), and that
a human should double check if the bot re-flags anything on its next pass. This keeps the
dismissal auditable — it is not a silent override.

If any of the three conditions doesn't hold yet, don't dismiss — just let the loop continue; the
bot usually clears itself within a cycle or two once it re-scans the new commits.

## Step 3 — decide: continue, STOP, or done

After each iteration, check in this order:

1. **Human-blocker flag set** → STOP the loop (`ScheduleWakeup stop: true`), and surface the
   specific comment/thread to the user via `AskUserQuestion` or plain text — this needs a human
   call, not another cycle.
2. **CI green AND no bot or human review at `CHANGES_REQUESTED` AND no untraced comments** (the
   same bar as `/ansh-resolve`'s Completion status section) **AND no unanswered human comment**
   (Step 1) **AND `vitalize-agent` has passed the head with no open findings** (Step 1.4) → converged. Go to Step 4. "CI green"
   means every required check's Buildkite build **for the head commit** has passed (Step 1.5
   step 2). A green build for an older commit does not count, and a "known" failure counts only
   if it is not a required check.
3. **Otherwise** → still work to do. Continue (see Step 5's cadence).

**Safety cap:** if you've run 12 iterations (~1 hour at 5-minute cadence) without converging, stop
and report to the user what's still blocking rather than looping indefinitely — a PR that hasn't
converged in an hour of automated passes needs a human look, not more cycles.

## Step 4 — converged: merge per the user's chosen mode

Once Step 3 condition 2 is met, stop the recurring loop (`ScheduleWakeup stop: true`), then act
on the `merge=` mode the user chose at the gate.

**Manual review called:** normally this is caught in step 1a, before the loop starts. If a
re-triage turns `manual-review` later (a loop fix touched a shared contract, or the plan
changed), stop the loop whether or not CI is green, don't merge, make sure the merge-call comment
is current, `PushNotification` "PR #<n> needs your review: <reason>", unwatch the PR, and end with
**STOPPED_FOR_HUMAN**.

**`merge=auto`:** first re-check that nothing new appeared since the gate:
- no new human or bot finding of major-or-worse severity in this PR's threads;
- no head commits beyond the gate's fixes and the loop's own mechanical fixes;
- every `Depends on #<n>` PR has merged, the PR targets the branch it should now target, and
  `origin/<base>` is merged in (stacking, "Merge order").

A dependency that is still open means wait, not merge: keep the watch on, and say which PR it is
waiting for. If everything holds, merge with
`gh pr merge <n> --squash` (or the repo's usual method), then `PushNotification` the result. If
a base-branch rule blocks a direct merge (for example the deploy-line-stopped ruleset on
`main`), use `gh pr merge <n> --squash --auto` so GitHub merges once the rule clears. If a new
major-or-worse finding did appear, fix it the same way as the gate's majors, then merge. Only a
finding that needs a user decision **downgrades to `ask`**, and you say why.

**`merge=ask`** (or the mode is missing for any reason) — ask:

```
AskUserQuestion:
  question: "PR #<n> is green and unblocked — merge it now?"
  options:
    - "Merge now" — squash-merge via `gh pr merge <n> --squash` (or the repo's usual merge method)
    - "Not yet" — leave it as is; you'll merge manually when ready
```

Never call `gh pr merge` without either `merge=auto` from the gate (with an `auto` merge call
and every dependency merged) or this confirmation, even if every check is green. Send a
`PushNotification` alongside the question if the user may be away — this is the payoff moment of
an unattended loop and worth surfacing even if they're not watching the terminal.

## Step 5 — cadence (dynamic self-pacing, same mechanism as `/loop`)

**Choose the supported backend first.** If the host provides a native PR watcher, register
this PR and yield so it can wake the session; retain the reviewed head, merge mode and iteration
counter in `.ansh/`. On T3 use its PR watcher when exposed, and unwatch when handing the PR back.
Do not also arm a second monitor or scheduler. If the host has session wakeups, use the legacy
mechanics below with its actual tool schemas. `Monitor`, `ScheduleWakeup`, `TaskList` and
`PushNotification` are capability examples, never calls to absent tools.

With neither watcher nor scheduler, poll in the active session at 300-second intervals, up to
the existing 12-iteration cap. Use interruptible waits in chunks of at most 60 seconds, check
for user cancellation and report progress during the wait. Persist counters in `.ansh/` and
run the same triage and STOP checks on every iteration. Use ordinary progress messages when
notifications are unavailable. If the host cannot keep an active wait, report
STOPPED_FOR_HUMAN with the current PR state and resume command; never claim a wakeup was armed.
The remaining numbered steps apply only when the host exposes those scheduling capabilities.

This is a session-scoped recurring loop, not a durable cron job — implement it the way `/loop`'s
dynamic mode does, not via `CronCreate` (fixed cadence, 7-day auto-expire, and no way to carry the
stuck-bot counters/human-blocker state between fires).

1. Run Step 1 now (don't wait for the first tick).
2. If CI is currently running, arm a `Monitor` on the build so a finish wakes the loop immediately
   instead of waiting out the fallback delay. Check `TaskList` first — don't double-arm across
   iterations.
3. Decide continue/STOP/done per Step 3.
4. If continuing, call `ScheduleWakeup` with `delaySeconds: 300`. **Always exactly 300, never
   600 or more:** the user asked for every 5 minutes, not 10. It is a fixed cadence, not an
   idle-tick default, and it does not stretch while waiting on CI or a bot (the `Monitor` in
   step 2 handles the faster wake) and `prompt` set to re-invoke this skill
   (`/ansh-pr-loop <n> reviewed merge=<auto|ask>`: carry the PR number and the gate's outcome
   explicitly in the prompt, so a fresh fire neither re-derives the PR nor re-runs the gate nor
   loses the user's merge choice) — same pattern as `/loop`'s dynamic mode, just always the same delay rather than
   observation-based pacing.
5. If a `<task-notification>` fires from the armed Monitor before the 5-minute deadline, treat it
   as this iteration's trigger — run Step 1 immediately, then re-arm per Step 3/4.
6. Briefly state, before calling `ScheduleWakeup` each time: current CI/review state, what changed
   this iteration, and what's still blocking. Keep it short — this runs a dozen times, not once.

## STOP points (in addition to the human-blocker flag in Step 3)

- An `/ansh-review` plan gap that is extra scope, or a plan that looks stale (step 1b): ask the user
  before splitting the PR or editing the ticket or TDD.
- A reviewer comment implying a scope change → route to `/ansh-plan`, don't absorb it silently
  (same rule as `/ansh-resolve`).
- Dismissing a bot review when any of the three Step 2 conditions is uncertain — don't guess;
  treat uncertainty as "not yet" and let another cycle pass instead.
- The safety cap (12 iterations) is hit.

## Outcome ledger

Every run of this skill writes how it ended, so you can count how many PRs actually
auto-merge. Append one JSON line to `~/.agentic-workflow/ansh-pr-loop/outcomes.jsonl` (create
the directory if needed) each time the loop merges a PR or ends with a completion status:

```json
{"ts":"<ISO time>","repo":"<owner/repo>","pr":<n>,"head":"<sha>","via":"<ansh-loop | ansh-small-loop | direct>","merge_call":"<auto | manual-review | cleared-by-review>","outcome":"<auto_merged | user_asked_merge | waiting_on_parent | needs_review | needs_decision | safety_cap | stopped_by_user>","waiting_on":[<n>],"reason":"<one line>"}
```

- `via` is `ansh-loop` or `ansh-small-loop` when that skill invoked this one (it passes
  `via=<name>` in the arguments), otherwise `direct`.
- `auto_merged` means this loop ran `gh pr merge` under `merge=auto` with no confirmation asked.
  `user_asked_merge` means the user said to merge (`merge=ask`, or "merge it").
- Write a new line when a waiting PR later merges. Don't rewrite old lines, so the file is a
  history.

**`/ansh-pr-loop stats`** reads the ledger and reports, for a date range (default: the last 7
days): PRs by latest outcome, the auto-merge rate overall and for `via=ansh-loop`, and every PR
whose latest outcome is `needs_review`, `needs_decision` or `waiting_on_parent`, with how long it
has waited.

## Completion status

Before ending, write the outcome line (Outcome ledger above).

End each Step 4/STOP with one of:
- **DONE** — converged and either auto-merged (`merge=auto`) or the user answered the merge
  question (merged or declined).
- **STOPPED_FOR_HUMAN** — `/ansh-review` called manual review (say why and what to look at),
  human-blocker flag, or safety cap hit; state exactly what's needed.
- **STOPPED_BY_USER** — user asked to cancel mid-loop.
