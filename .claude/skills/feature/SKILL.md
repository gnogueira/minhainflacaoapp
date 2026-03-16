---
name: feature
description: Use when the user asks to build, add, or implement a new feature or
  behavior change. Do NOT use for bug fixes. Classifies complexity, sets up git
  branch and state folder, then routes to the correct development track.
---

You are the entry point for the feature development pipeline of **Minha Inflação**.

## Step 1 — Classify complexity

Use the criteria below to decide the track. Print your reasoning visibly before routing.

### Fast-track (skip PRD, go straight to feature-plan with a brief)
A change qualifies as fast-track when ALL of the following are true:
- Alters only text content or moves existing UI elements around
- Touches ≤ 2 files

If the user passes `--full`, always use full-track regardless.

### Full-track (discovery questions first, then feature-plan)
Everything else: new endpoints, new screens, new Firestore collections, new business logic, new dependencies.

### Bug / hotfix
Out of scope for this pipeline. Tell the user: "This sounds like a bug fix — use a direct fix approach instead of the feature pipeline."

---

## Step 2 — Read fast_track_count

Check `.claude/features/` for existing `status.md` files and count how many consecutive fast-track features exist (i.e., the last N features all have `track: fast`). If the count reaches 3, surface this nudge **before routing**:

> "Fast-track has sido usado 3 vezes seguidas. Considere se esse trabalho faz parte de uma feature maior que merece um PRD."

---

## Step 3 — Generate slug and set up state

1. Create a kebab-case slug from the feature request (max 5 words). Example: `comparacao-regional-de-precos`.
2. Run:
   ```
   git checkout -b feature/{slug}
   ```
3. Create folder `.claude/features/{slug}/` and write `status.md`:

```
slug: {slug}
phase: planning        ← fast-track starts here; full-track starts at: discovery
track: fast | full
branch: feature/{slug}
prd_approved: false    ← fast-track: set to true immediately after writing brief
plan_approved: false
active_task: null
fast_track_count: {N}  ← count of consecutive fast-track features including this one
open_majors: []
```

For **fast-track**: write a one-paragraph brief in `status.md` under a `brief:` key, then immediately set `prd_approved: true`.

---

## Step 4 — Route

**Fast-track:** Tell the user:
> "Classificado como **fast-track**. Branch `feature/{slug}` criada. Passando para planejamento — use `/feature-plan` para continuar."

**Full-track:** Run discovery — ask the user the following questions one at a time:
1. What problem does this solve for the user?
2. Who is the primary user (anonymous, authenticated, admin)?
3. Are there any Firestore schema changes needed?
4. Are there any new API endpoints needed?
5. Are there any edge cases or constraints we should design for upfront?

After discovery, summarize answers as a PRD draft in `.claude/features/{slug}/prd.md` and ask the user for approval. Only set `prd_approved: true` in `status.md` after explicit approval. Then tell the user:
> "PRD aprovado. Branch `feature/{slug}` criada. Use `/feature-plan` para continuar."
