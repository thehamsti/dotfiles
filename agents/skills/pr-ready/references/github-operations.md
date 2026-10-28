# GitHub operations

Use these with the live repository/PR, never a hardcoded personal repo. The
examples assume `REPO=owner/repo`, `PR` is the number, and `HEAD` is the PR head
SHA you just fetched. Determine the base/head and fork routing before publishing.
Use an explicit `--repo` or API repository path so another checkout cannot change
the target. Discover the skill's directory from the loaded `SKILL.md`; do not
assume a Codex-specific home path.

## PR and checks

```bash
gh auth status
gh repo view --json nameWithOwner,defaultBranchRef
gh pr view "$PR" --repo "$REPO" --json number,url,state,isDraft,headRefName,headRefOid,headRepositoryOwner,baseRefName,mergeable,mergeStateStatus,reviewDecision
gh pr checks "$PR" --repo "$REPO" --json name,state,bucket,link,workflow
gh api --paginate "repos/$REPO/commits/$HEAD/check-runs?per_page=100"
gh api --paginate "repos/$REPO/commits/$HEAD/statuses?per_page=100"
```

Checks must belong to the current head. For repeated legacy status contexts use
their newest status; inspect workflow attempts before treating an older failed
attempt as a current failure. Do not limit inspection to required checks when
other applicable checks are failing. Check the repository's workflows/rules
when an expected check is missing or the rollup is empty.

Create a PR without `--draft`; use the real repository template and actual values:

```bash
gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"
gh pr ready "$PR" --repo "$REPO"
gh run view "$RUN_ID" --repo "$REPO" --log-failed
gh run rerun "$RUN_ID" --repo "$REPO" --failed
```

## Complete review state

```bash
gh api --paginate "repos/$REPO/pulls/$PR/reviews?per_page=100"
gh api --paginate "repos/$REPO/issues/$PR/comments?per_page=100"
```

Fetch `repository.pullRequest.reviewThreads` with GraphQL. Include thread `id`,
`isResolved`, `isOutdated`, file/line anchors, and comments with author login,
body, URL, created/updated times, and commit OID where available. Follow thread
`pageInfo` cursors **and** each thread's nested comment cursors. Resolve the
GraphQL owner/name from `REPO`, and use the PR number as an integer.

Only published reviews count as complete; `PENDING` reviews do not. Review
`commit_id` associates a published review with a head. Read later bot edits and
review-body findings as well as line comments. Keep a small ledger keyed by
thread/comment ID and review ID: latest content/update time, relevant SHA,
disposition, pushed fix commit or explanation link, and resolution state.
Track the current Greptile request's PR-comment ID/time to avoid duplicate pings.

For thread replies, write the explanation to a temporary UTF-8 file. GitHub CLI
`-F body=@file` reads its contents without interpolating them as shell code:

```bash
gh api graphql -f query='mutation($threadId:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId,body:$body}){comment{url}}}' -F threadId="$THREAD_ID" -F body=@"$BODY_FILE"
gh api graphql -f query='mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId}){thread{id isResolved}}}' -F threadId="$THREAD_ID"
```

Check the returned `isResolved` value. Re-fetch the thread after mutations.
For a standalone PR-comment finding, reply with a PR comment linking the
original comment and giving its disposition; do not invent a thread ID.

## Re-review

Write exactly `@greptileai` into a temporary file and post it once for the review
cycle that needs it:

```bash
gh pr comment "$PR" --repo "$REPO" --body-file "$BODY_FILE"
```

This request is not a completed review. Poll for a new completed Greptile run
and current-head score. If a summary is edited in place, preserve the review/run
association instead of accepting whichever historical comment contains `4/5`.
Do not install/configure new GitHub Apps or post additional bot triggers without
a separate task requiring them. Cursor/Bugbot normally rechecks pushes through
the repository's existing integration; inspect its actual check/review state.

## Stable handoff

Record UTC observations, head SHA, check/run IDs and conclusions, latest bot
review IDs/times, comment edit times, unresolved thread IDs, score association,
and the quiet-window start. Re-fetch everything for the final two observations.
Any head change invalidates old checks/score and requires validation of the new
commit. Access/rate-limit errors are missing evidence, not an empty inbox.
