---
name: claude-fix-prompt
description: Rewrite a prompt into a deeper version of the same task, not a bigger one. Before rewriting, answer four questions — what a top professional in the field would do that the prompt isn't asking for, the rawest material they would start from instead of pre-digested summaries, the specific methods and tools they would use, and what (other than the model or the user) would show the result is right — then rewrite the prompt to ask for exactly that. Use when the user says "/claude-fix-prompt", "fix this prompt", "make this prompt deeper", "sharpen this prompt", or pastes a prompt and asks how to make it better.
---

# /claude-fix-prompt — Deeper, not bigger

Takes a prompt the user is about to send (to Claude or any other model/agent) and rewrites it
so the task gets done the way a top professional in that field would do it. The rewrite is
**deeper, not bigger**: same scope, same deliverable, but grounded in primary sources, real
methods, and an external check on correctness. Do not inflate the task, add sections the user
didn't ask for, or widen the deliverable.

## Input

The prompt to fix is `$ARGUMENTS`. If `$ARGUMENTS` is empty, use the most recent prompt the
user wrote in this conversation that reads like a task. If there is still nothing to work with,
ask the user to paste the prompt.

If the prompt's field is ambiguous (it could be a legal question or a product question, say),
pick the most plausible field, state the assumption in one line, and proceed. Don't block on it.

## Procedure

Answer the four questions **before** writing the rewrite, and show the answers to the user.
Keep each answer tight: a few bullets, not an essay. The analysis is what makes the rewrite
good, so don't skip to the rewrite.

### 1. What a top professional would do that the prompt isn't asking for
Name the concrete moves an expert in this field makes by reflex that the prompt leaves out.
Think: the step they never skip, the question they always ask first, the failure mode they
check for, the standard they hold the output to. These are *depth* moves within the existing
task, not extra deliverables.

### 2. The rawest material they would start from
Name the primary sources the professional would go to instead of whatever has already been
digested, summarized, or paraphrased for the user. Examples by field: the actual statute or
case law rather than a blog summary; the raw logs, traces, and query plans rather than the
dashboard; the source code rather than the README; the original paper and its data rather
than the press release; the transcript rather than the meeting notes; the contract rather
than the term sheet. Be specific about *which* raw material, not "primary sources" in general.

### 3. The specific methods and tools they would use
Name the actual techniques, frameworks, instruments, or tools the professional would reach
for — by name. "Run a profiler" is weak; "flamegraph from `perf record` on the hot path" is
right. "Check the numbers" is weak; "reconcile against the audited 10-K and recompute the
ratio from the line items" is right. Include the method's standard output or artifact when
there is one.

### 4. What, other than the model or the user, would show the result is right
Name an **external** check: a test that passes, a reproduction that matches, a number that
reconciles to an independent source, a spec or standard the output can be diffed against, a
second dataset, a domain expert's known-good example, a prediction that can be verified.
Neither the model's confidence nor the user's approval counts. If no external check exists
for this task, say so plainly and name the closest proxy.

### 5. Rewrite the prompt
Rewrite the user's prompt so it asks for exactly what steps 1–4 surfaced:

- Keep the user's original goal, scope, and deliverable. Same task, done deeper.
- Fold in the expert moves from (1) as explicit instructions.
- Direct the work at the raw material from (2), and say to prefer it over secondary sources.
- Name the methods and tools from (3) as the expected approach.
- Require the external check from (4) and ask for it to be reported alongside the result.
- Preserve the user's voice and any constraints they already stated (length, format, tone,
  audience, deadline). Don't add new constraints they didn't imply.
- Keep it as short as it can be while asking for all of the above. A deeper prompt is not a
  longer prompt for its own sake.

Deliver the rewritten prompt in a single fenced code block so it can be copied as-is.

## Output format

```
## 1. What a top professional would do that you're not asking for
- ...

## 2. Rawest material to start from
- ...

## 3. Methods and tools
- ...

## 4. External check that the result is right
- ...

## Rewritten prompt
```text
<the rewritten prompt>
```
```

End there. No closing offer, no summary of what you changed.

## Guardrails

- **Deeper, not bigger.** If the rewrite adds a deliverable the original didn't ask for, cut it.
- **No padding.** Each of the four sections should be a handful of specific bullets. Generic
  advice ("be thorough", "cite sources") fails the skill; name the thing.
- **Don't do the task.** This skill fixes the prompt. It does not answer the prompt. If the
  user wants the task done too, they run the rewritten prompt next.
- **Field-specific over generic.** Every bullet should be something a non-expert would not
  have thought to say. If a bullet would apply to any task in any field, sharpen it or drop it.
