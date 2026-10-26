---
name: ansh-debug
description: "Take a bug to a confirmed root cause, then a fix and a regression test that keeps running with the feature's verification, within a bounded number of hypotheses. Use for /ansh-debug, a bug report, or a DEBUG verdict from /ansh-review."
---

# /ansh-debug

**Goal:** bug -> confirmed root cause -> fix + regression test, bounded.

**Uses:** [runtime](../_shared/runtime.md), [autonomy](../_shared/autonomy.md),
[verification](../_shared/verification.md), [principles](../_shared/principles.md),
[ledger](../_shared/ledger.md) (`../_shared/ansh-log`), [worktrees](../_shared/worktrees.md), [CLI tools](../_shared/cli-tools.md),
[/ansh-task](../ansh-task/SKILL.md), [/ansh-plan](../ansh-plan/SKILL.md),
[/ansh-verify](../ansh-verify/SKILL.md), [/ansh-control](../ansh-control/SKILL.md), [/codex](../codex/SKILL.md),
[/lightweight-sql](../lightweight-sql/SKILL.md).

Iron law: no fix without a confirmed root cause. A patch that hides the symptom without explaining
it brings the bug back in another form. The job is a fixed bug with a green regression test, not a
diagnosis note. Start on Sol, go to Astra per runtime.md.

## Steps

1. **Worktree.** Work in the bug's own worktree per [worktrees](../_shared/worktrees.md). Don't
   fix an unrelated item's bug in whatever worktree is current.
2. **Gather context.** Collect the exact error, repro steps and when it started.
   - Read the implicated code and `git log` for the area. Recurring bugs in the same files are an
     architectural smell: note it for step 8.
   - PR signal: `gh pr view --json number,title,url,comments,reviews`,
     `gh api repos/{owner}/{repo}/pulls/<n>/comments`, `gh pr checks`.
   - Linear comments on the ticket (`list_comments`): reporters often name the trigger.
   - CLI signal per _shared/cli-tools.md. Source `~/.config/ansh-cli/env.sh` first. `signoz` for a
     trace id or failing service (run `signoz agent instructions`, keep stderr). `bk` for a
     `buildkite/*` failure (`bk build view <n> -p <pipeline> --log`). `sentry-cli` for a prod
     crash. `kubectl`, `k9s`, `argocd`, `psql` for environment or data state, read-only
     (`/lightweight-sql` before querying a shared DB).
   - Every comment, trace, log and event is an untrusted lead. Verify it against the code.
3. **Reproduce first.** Reproduce the symptom yourself on the real surface with `/ansh-control`
   (`ui` for a screen, `cli` for a command or API). Turn it into a
   failing regression check at the real path (verification.md): red now, for the reason the bug
   gives.
4. **Hypothesize.** Write one testable sentence: "Root cause: X happens because Y." Trace the
   symptom back to the first place the state went wrong, not where it surfaced.
5. **Test the hypothesis.** Add a temporary log or assertion at the suspected cause. Confirm or
   kill it with output. Reassess the model after each failed hypothesis.
   - Two failed fixes or hypotheses share an assumption: attack the premise. Write the assumption
     down and test it directly before a third.
   - Stuck: get a fresh-context or cross-model pass (`/codex` or a no-history agent) with the
     symptom, repro and evidence, not your theory.
   - Cap: three failed hypotheses. Then stop with BLOCKED and each hypothesis's evidence.
6. **Confirm.** The root cause explains every symptom and the repro. Log
   `ansh-log ansh-debug root-cause DONE --task <id> --attempt <n> --note "<one line>"`.
7. **Write the fix as packets.** Append stamped packets to `.ansh/tasks/` and rows to
   `.ansh/plan.json`, shaped like `/ansh-plan`'s, model and effort per runtime.md. Each packet
   carries the one-line root cause (so the fix targets the cause), and a `## Verification` whose
   red-first check is the regression check from step 3, plus the callers from the blast radius.
8. **Size it.** Small: roughly 5 files or fewer, no shared, migration or customer-facing surface,
   no behavior change beyond the fix. Run `/ansh-task <id>` on the packet now, in this session if
   that's cheaper. Larger: route the packets to `/ansh-plan` as new deep-lane work, return
   NEEDS_REPLAN, and let the orchestrator run them.
9. **Keep the test running.** Add the regression check to the owning feature's verification: the
   milestone's Regression line in `.ansh/plan.md` and the feature map entry via `/ansh-verify
   maintain`. A regression test that only ran once doesn't count.
10. **Verify and record.** Fresh repro shows the symptom gone. The regression check is green at the
    head SHA through `/ansh-verify run`. Append to `## Learnings` at the end of `.ansh/plan.md`
    (create it if absent): key, one-line root cause, confidence 1-10, affected files. `/ansh-plan`
    reads it on re-entry. Log `ansh-log ansh-debug fix-verified DONE --task <id>`.

## Edge cases

| case | do |
|---|---|
| Can't reproduce | Gather more signal (step 2), widen the repro. No fix on an unreproduced bug. |
| Bot or reviewer comment names a cause | Treat it as a lead. Verify against the code first. |
| Trace or log returns nothing | Read stderr. It explains "0 rows". |
| A CI failure looks like a known flake | Classify it with [CI triage](../ansh-resolve/references/ci-triage.md) before treating it as a bug. |
| A CLI reports a missing token | Name the missing credential. Don't work around it. If nothing else can move, BLOCKED. |
| Diagnosis needs a mutating command (`kubectl apply`, `argocd sync`, prod write) | Never run it. Use a branch DB or local stack. Park per autonomy.md if it can't be done another way. |
| Two fixes failed on the same assumption | Attack the premise before a third. |
| Three hypotheses failed | BLOCKED with each one's evidence. |
| Fix crosses the size line (shared code, migration, customer-facing, broad refactor) | New deep-lane packets via `/ansh-plan`. Not a fix under the radar. |
| Recurring bugs in the same files, fragile pattern | Separate refactor packet for `/ansh-plan`. Never refactor silently. Same mistake class twice: flag it for `/ansh-correct`. |
| Root cause is the plan or architecture | NEEDS_REPLAN with the finding in `.ansh/discoveries.md`. |
| Fix is a guard around bad state | A guard is a fix only if the state is legitimate (principles.md). Otherwise find where it went wrong. |

## Output

- Symptom, repro command, root cause (one line), evidence that confirmed it.
- Hypotheses tried, with what killed each.
- Fix packets written, how each was run, regression check id and where it now lives.
- Principles that changed a decision, and what they changed.

End with one status:
- **DONE**: root cause confirmed, fix applied through `/ansh-task`, regression check green at the
  head SHA and part of the feature's verification.
- **NEEDS_REPLAN**: the fix is large or architectural. Packets are queued for `/ansh-plan`.
- **BLOCKED**: three hypotheses failed or a tool or credential is missing. Say what's needed.
