# Principles

The bar every `/ansh` skill holds work to. Adapted from pstack. When a principle changes a
decision, name it in your report and say what it changed.

| Principle | When | Rule |
|---|---|---|
| Name the data shape | Before any logic | Pick the types, schema or state machine first. Encode the domain in a structure, not scattered conditionals. |
| Smallest change | Sizing any diff | Bias to deletion. Subtract dead weight before adding. No "while I'm here". |
| Prove it works | Before saying done | Check the real artifact (run it, read the value), not a proxy or a self-report. See [verification](verification.md). |
| Red first | Any behavior change | Write the check, watch it fail, then change code. |
| Test behavior | Writing or keeping a test | Assert what callers observe. The test fails when behavior breaks and survives a refactor. |
| Fix root causes | Debugging | Trace the symptom to the first place it went wrong. A guard is a fix only if the state is legitimate. |
| Attack the premise | Two fixes sharing an assumption failed | Write the assumption down and test it directly before a third fix. |
| Explain the number | Any measurement | Find what limits it. Rule out that it measured something else. Repeat runs. |
| Small verifiable units | Multi-step work, commits, PRs | Each unit ends in a passing check before the next starts. |
| Build the lever | Non-trivial or repeated work | Write the script, codemod or check that does or proves it. The tool is what a reviewer reruns. |
| Boundary discipline | Validation, errors, adapters | Guard at system edges, trust internal types, keep business logic pure. |
| Idempotent operations | Jobs, migrations, retries | Converge to the same end state after a partial run. |
| Encode lessons in structure | A mistake repeats | Make it impossible (types, lint, CI) instead of writing another rule. See `/ansh-correct`. |
| Prototype instead of asking | A fact is unknown | Run something. Ask nobody. See [autonomy](autonomy.md). |
