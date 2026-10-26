# `.ansh/plan.json`

The machine index the loops read. `/ansh-plan` writes it. Loops and `/ansh-task` update `status`,
`merge_state`, and `prs[].base` when a stack is retargeted (stacking). Nothing else.

```json
{
  "goal": "one-line restatement",
  "source": "REV-1157 | prose",
  "tdd": "https://linear.app/... | null",
  "parent_ticket": "REV-1157",
  "integration_branch": "rev-1157-payrule-thresholds",
  "branch_suggestion": "rev-1157-payrule-thresholds",
  "definition_of_done": "the overall bar, one line",
  "guardrails": [
    "no schema change to `shift` without a reversible migration",
    "no writes to prod data (autonomy never-do list)"
  ],
  "acceptance_criteria": [
    { "id": "AC-1", "text": "a manager sees the +4/+8 override after PTO without a reload", "inferred": false },
    { "id": "AC-2", "text": "Given an overnight shift, when ..., then ...", "inferred": true }
  ],
  "exit_criteria": [
    "a task's verification still fails after 3 rounds and one replan",
    "whole-goal evaluation fails twice",
    "a guardrail above is tripped",
    "nothing left can move without a parked item"
  ],
  "agent_defaults": ["D-3", "D-4"],
  "termination": {
    "max_rounds_per_task": 3, "replans_per_task": 1,
    "max_goal_evaluations": 2,
    "quality_bar": "every verification contract passes at the head SHA and /ansh-review returns PASS"
  },
  "milestones": [
    { "id": "M1", "title": "schema and migration", "surface": "invisible",
      "covers": ["AC-1", "FM-2"], "depends_on": [], "parked_at_merge": false }
  ],
  "prs": [
    { "id": "PR1", "milestone": "M1", "branch": "rev-73-tag-rules-engine",
      "base": "rev-1157-payrule-thresholds",
      "links": [{ "ticket": "REV-73", "word": "Closes" }, { "ticket": "REV-77", "word": "Part of" }],
      "depends_on": [], "subtasks": ["T1", "T2"], "parked_at_merge": false, "merge_state": "todo" }
  ],
  "subtasks": [
    { "id": "T1", "title": "...", "milestone": "M1", "tier": "standard", "model": "gpt-6.1-sol",
      "effort": "high", "deps": [], "fresh_eyes": "independent", "surface": "invisible",
      "covers": ["AC-1"], "autonomy": "full", "parked_at_merge": false,
      "linear_ticket": "REV-73", "pr": "PR1", "packet": ".ansh/tasks/T1.md", "status": "todo" }
  ]
}
```

## Rules

- `guardrails`, `acceptance_criteria` and `exit_criteria` are required on every plan. `/ansh-loop`
  sends a plan without them back to `/ansh-plan`.
- `acceptance_criteria` holds the AC-n list, numbered and binary. `inferred: true` marks ones the
  planner derived. Don't repeat them per task: a task's `covers` and its packet's Verification are
  its bar.
- `parent_ticket` is context, status and the umbrella PR's link.
- `prs[].links` and every branch name follow [tickets](../../_shared/tickets.md). A ticketless goal
  has empty `links`.
- `prs[].depends_on` lists the PR ids this one stacks on or merges. They render as `Depends on #<n>`.
- `prs[].base` follows [stacking](../../_shared/stacking.md). Single-PR plan: `base` is `main`,
  `integration_branch` is null, and `branch_suggestion` is the only branch.
- `linear_ticket` is a string or array. A PR's `links` cover the `linear_ticket`s of its subtasks.
  Omit it only for untracked scaffolding noted in `plan.md`.
- `autonomy` is `full` on every task. `parked_at_merge: true` on a task, its PR and its milestone
  when the milestone has an irreversible rollout step or its merge destroys or rewrites data.
- `status`: `todo`, `in_progress`, `needs_replan`, `done`, `parked`.
- `merge_state`: `todo`, `open`, `waiting` (on a dependency), `parked`, `awaiting_approval`, `merged`.
