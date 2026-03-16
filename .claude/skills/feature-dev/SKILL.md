---
name: feature-dev
description: Use when a feature plan is approved and development needs to start.
  Implements each task using TDD, commits per task, and triggers story E2E tests
  when all tasks in a story are done.
---

You are the development stage of the **Minha Inflação** feature pipeline.

**REQUIRED SUB-SKILL:** Before writing any code, invoke `superpowers:test-driven-development` and follow it throughout this skill.

## Step 1 — Precondition check

Read `.claude/features/*/status.md` for the active feature (current branch or most recently created).

**Refuse to start if:**
- `plan_approved: false` — tell the user: "O plano ainda não foi aprovado. Execute `/feature-plan` primeiro."

Load `plan.md` and `test-plan.md` from the feature state folder.

---

## Step 2 — Task loop

Repeat the following for each task in order (following the epic → story → task hierarchy in `plan.md`):

### 2a. Set active task
Update `status.md`: `active_task: {task-id}` (e.g., `E1-S1-T1`).

### 2b. Write the failing test FIRST
- Write the unit test for this task.
- Run: `cd backend && npm test`
- **Confirm the test is RED (failing).** Do NOT write implementation code until the test exists and is failing.

### 2c. Write minimal implementation
- Write the minimum code to make the test pass.
- Run: `cd backend && npm test`
- Confirm all tests are GREEN.

### 2d. Refactor if needed
- Clean up without changing behavior.
- Run: `cd backend && npm test` again to confirm still GREEN.

### 2e. Commit
```
git commit -m "task({story-id}): {task description}"
```
Example: `git commit -m "task(E1-S1): add JWT validation middleware"`

### 2f. Mark task complete
Update `status.md`: set this task as done in the task list.

---

## Step 3 — Story completion trigger

When **all tasks in a story** are done:

- Run story-level E2E: **[PENDING — E2E not yet configured]**
  - When E2E is configured, run: `flutter test integration_test/ --name "{story name}"` or the equivalent configured command.
  - If E2E fails, treat as a **BLOCKER** — do not move to the next story until resolved.
- Update `status.md`: mark the story as complete.
- Tell the user: "Story {story-id} completa. Todos os testes passaram."

---

## Step 4 — Epic completion trigger

When **all stories in an epic** are done:

- Run epic-level E2E: **[PENDING — E2E not yet configured]**
  - When E2E is configured, run the epic-level integration suite.
- Update `status.md`: mark the epic as complete.
- Tell the user: "Epic {epic-id} completo."

---

## Step 5 — Feature completion

When all epics and stories are done:

- Update `status.md`: set `phase: review`, `active_task: null`.
- Tell the user:
  > "Todas as tasks implementadas e commitadas. Feature `{slug}` pronta para review. Quando o staging estiver configurado, use `/feature-review` para continuar."
