---
description: "Stage → commit → sync (pull) → push in one shot. Linear by default."
argument-hint: "[message] | --amend [message] | --no-push [message] | --merge | --no-fetch | --force-if-rebased"
---

# Git Helper (human-friendly)

**Goal:** make a single, safe commit and push while keeping history clean. Defaults to a **linear** workflow (pull with rebase), but supports regular merges if your team prefers that.

## Flags (you can keep using these)
- `--amend` — amend the previous commit (message rules still apply).
- `--no-push` — do everything except push; show the new commit SHA.
- `--merge` — use a merge-based sync (`git pull`) instead of rebase (`git pull --rebase`).
- `--no-fetch` — skip the sync step (not recommended).
- `--force-if-rebased` — if a rebase occurred and a normal push is rejected, allow a guarded `--force-with-lease` push **only on non‑protected branches**.

**Protected branches:** `main`, `master`, `develop`, any `release/*` (never force-push).

---

## TL;DR Flow

1) **Commit message**
   - If you pass text, use it as the full message.
   - If not, write a short **Conventional Commit** title (≤72 chars) + 1–3 bullets from the diff.
   - If `--amend`, amend the prior commit with the same rules.

2) **Stage & commit**
   - Stage all changes.
   - If nothing changed → say “No changes to commit.” and stop.
   - Create (or amend) the commit and capture the short SHA + the first line of the message.

3) **Sync with remote**
   - **If no upstream exists** (brand-new branch): skip sync.
   - **If upstream exists:**
     - **Default (linear):** `git pull --rebase` (fast-forwards if possible; otherwise rewrites your local commits on top of remote to avoid merge bubbles).
     - **If `--merge`:** do a normal `git pull` (may create a merge commit).
     - **If `--no-fetch`:** skip this step.
   - **If there are no remote commits** for this branch: pull will say *Already up to date* or fast-forward trivially—no extra work.

4) **Push**
   - If `--no-push`, print the new commit info and stop.
   - Otherwise, try a normal `git push`.
   - If the push is rejected because you **rebased**:
     - If `--force-if-rebased` **and** branch is **not protected**, push with `--force-with-lease`.
     - Otherwise, stop with a clear message explaining how to proceed (rerun with the flag or open a PR).

5) **Report**
   - Print the commit SHA, the first line of the message, the sync method used (rebase/merge/none), and whether the push succeeded.


---

## Merge conflict handling (LLM‑assisted)

If `git pull --rebase` or `git pull` hits conflicts:

1) **Stop and summarize**
   - Show: current branch, upstream, and the list of conflicted files.
   - For each file, display the conflict blocks (trimmed) with a short explanation of both sides (“theirs” vs “yours”).

2) **Offer AI help**
   - Propose a **per-file resolution plan** in plain English (why we keep/discard each side).
   - Generate **candidate patches** for each conflicted file (unified diff) that remove conflict markers and produce a compilable state.
   - Ask: “Apply suggested fix for _filename_? (yes/no/show alt)”

3) **Apply if approved**
   - Apply the chosen patch, stage the file, and move to the next.
   - When all files are resolved:
     - If rebasing: continue the rebase.
     - If merging: finish the merge commit with a clear message.

4) **Escape hatches**
   - Need to bail? Provide commands to abort (`git rebase --abort` / `git merge --abort`) and return to pre-sync state.
   - If auto-stash would help (local work-in-progress): suggest re-running the sync with auto-stash behavior enabled.



