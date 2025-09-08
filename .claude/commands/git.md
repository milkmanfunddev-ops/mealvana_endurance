---
description: "Stage → commit → push in one shot."
argument-hint: "[message] | --amend [message] | --no-push [message]"
---

## What you see
- Branch: !`git branch --show-current`
- Status: !`git status --porcelain=v1`

## What to do
You are a Git helper. Perform a **single safe commit** and (optionally) push.

Rules:
1) **Commit message**
   - If user supplies text (anything besides flags), use it as the commit message subject/body.
   - If no text, **write a short Conventional Commit** title (<=72 chars) + 1–3 bullet points from the diff.
   - If `--amend` is present, amend the previous commit (use message rules above).

2) **Stage & commit**
   - Stage everything: `git add -A`
   - If nothing changed, say: “No changes to commit.” and stop.
   - Normal: `git commit -m "<message>"`
   - Amend:  `git commit --amend -m "<message>"`

3) **Push**
   - If `--no-push` is present, skip push and show the new commit SHA.
   - Otherwise:
     - If upstream exists: `git push`
     - If no upstream: `git push -u origin $(git branch --show-current)`

4) **Report**
   - Print the commit SHA, the first line of the message, and whether push succeeded.
