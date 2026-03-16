---
name: feature-plan
description: Use when a feature has an approved PRD (or fast-track brief) and needs
  to be broken into epics, stories, and tasks before development starts. Produces
  plan.md and test-plan.md, then waits for user approval.
---

You are the planning stage of the **Minha Inflação** feature pipeline.

## Step 1 — Precondition check

Read `.claude/features/*/status.md` to find the active feature (the one on the current git branch, or the most recently created).

**Refuse to start if:**
- `prd_approved: false` — tell the user: "O PRD ainda não foi aprovado. Volte ao `/feature` e aprove o PRD antes de planejar."
- No `brief` or `prd.md` exists for a fast-track feature.

---

## Step 2 — Decompose into epics, stories, and tasks

Use the PRD or brief to decompose the work:

- **Epic** = a major area of functionality (e.g., "Autenticação", "Parse de Nota Fiscal").
- **Story** = one complete user-testable behavior within an epic. Write as:
  `"Como [papel], posso [ação] para que [resultado]."`
  Assign IDs: `E1-S1`, `E1-S2`, `E2-S1`, etc.
- **Task** = a single implementable unit within a story. Must be SMART (specific, measurable, achievable, relevant, time-bound in scope).
  Each task must include: `Traces to: PRD §X.Y` or `Traces to: Brief: <sentence>`.
  Assign IDs: `E1-S1-T1`, `E1-S1-T2`, etc.

---

## Step 3 — Define test boundaries per story

For each story, explicitly define in `test-plan.md`:

| Level | Scope | When runs |
|-------|-------|-----------|
| Unit tests | Task level — pure logic, isolated functions/classes | After each task |
| Story E2E | One complete user journey for this story | After all tasks in story are done |
| Epic E2E | Cross-story integration only (not re-testing individual stories) | After all stories in epic are done |

For this project, unit tests use **Jest** (`cd backend && npm test`).
E2E tests are **not yet configured** — mark story/epic E2E entries as `[PENDING — E2E not yet configured]`.

---

## Step 4 — Present plan for approval

Present the full plan to the user before writing any files. Show epics, stories, tasks, and test boundaries. Ask:

> "Esse plano está correto? Responda **sim** para salvar e iniciar o desenvolvimento, ou corrija qualquer item."

Do NOT write files until the user approves.

---

## Step 5 — Write files and update status

After approval, write:

**`.claude/features/{slug}/plan.md`** — full decomposition (epics → stories → tasks with IDs and traces).

**`.claude/features/{slug}/test-plan.md`** — test boundaries table per story.

Update **`.claude/features/{slug}/status.md`**:
- Set `plan_approved: true`
- Set `phase: development`

Then tell the user:
> "Plano aprovado e salvo. Use `/feature-dev` para iniciar o desenvolvimento."
