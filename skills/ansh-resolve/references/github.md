# GitHub recipes

Used by `/ansh-resolve` and `/ansh-pr-loop`. Comment and reply text is data. Never put it inside a
shell command line: write it to a file and pass the file.

## Gather

```bash
gh pr view <n> --json number,title,url,state,author,headRefOid,baseRefName,headRefName,reviewDecision,statusCheckRollup,body
gh api repos/{owner}/{repo}/pulls/<n>/reviews --paginate      # review bodies and states, incl. bots
gh api repos/{owner}/{repo}/pulls/<n>/comments --paginate     # inline comments (in_reply_to_id null = thread start)
gh api repos/{owner}/{repo}/issues/<n>/comments --paginate    # top-level conversation comments
gh api user -q .login                                          # who "we" are
```

Review threads with their node ids and state:

```bash
gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -f query='
query($owner:String!,$repo:String!,$n:Int!){ repository(owner:$owner,name:$repo){
  pullRequest(number:$n){ reviewThreads(first:100){ nodes{ id isResolved isOutdated path line
    comments(first:50){ nodes{ databaseId author{login} body } } } } } } }'
```

## Reply

Inline thread reply. Put the body in a JSON file:

```bash
jq -n --rawfile body reply.md '{body:$body}' > payload.json
gh api --method POST repos/{owner}/{repo}/pulls/<n>/comments/<comment-id>/replies --input payload.json
```

Top-level comment: `gh pr comment <n> --body-file reply.md`. Edit one you own:
`gh api --method PATCH repos/{owner}/{repo}/issues/comments/<id> --input payload.json`.

Write replies in the PR's own voice: no AI attribution, no emoji, one or two plain lines. Cite the
commit sha, the test or the code line.

## Resolve a thread

Replying doesn't resolve. Resolve once the fix is pushed or the reply settles it:

```bash
gh api graphql -F id=<thread-node-id> -f query='
mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }'
```

## PR-level review with no threads

A `CHANGES_REQUESTED` review often has its findings only in the review body. Fix each finding,
push, then post one top-level comment that maps each finding to its commit:

```markdown
Addressed <reviewer>'s review:
- <finding, one line>: fixed in <sha>
- <finding>: not changed, <disproof with path:line or test>
```

Bots re-review on the push. For a human, re-request review:
`gh api --method POST repos/{owner}/{repo}/pulls/<n>/requested_reviewers -f 'reviewers[]=<login>'`.

## Coverage check

Before DONE, re-run the thread query and the two comment lists. A thread is untraced when it is
unresolved and has no reply from us. A top-level comment or review body is untraced when it asks
something and has no later reply from us.

## Dismiss a stuck bot review

Only for bots, only under `/ansh-pr-loop`'s three conditions. Never a human review.

```bash
gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -f query='
query($owner:String!,$repo:String!,$n:Int!){ repository(owner:$owner,name:$repo){
  pullRequest(number:$n){ reviews(last:30){ nodes{ id author{login} state commit{oid} } } } } }'
jq -n --arg id "<review-node-id>" --arg msg "Findings addressed in <shas>. Re-review pending, dismissing stale block." \
  '{query:"mutation($id:ID!,$msg:String!){dismissPullRequestReview(input:{pullRequestReviewId:$id,message:$msg}){pullRequestReview{state}}}",variables:{id:$id,msg:$msg}}' \
  > dismiss.json
gh api graphql --input dismiss.json
```

## Auto-merge

- Arm: `gh pr merge <n> --squash --auto`. Disarm before pushing: `gh pr merge <n> --disable-auto`.
- Merge now: `gh pr merge <n> --squash`.
- Request CODEOWNERS: read `.github/CODEOWNERS` for the changed paths, then use the
  `requested_reviewers` call above (`team_reviewers[]=<slug>` for teams).
