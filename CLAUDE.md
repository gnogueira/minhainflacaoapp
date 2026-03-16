# Minha Inflação — CLAUDE.md

## Project Overview

Flutter app (Android + iOS) that lets users photograph Brazilian receipts (notas fiscais), extract products and prices via Gemini Vision API, build a personal spending history, and compare prices anonymously with other users in the same region (by partial CEP).

## Architecture

```
Flutter App (Android + iOS)
       │
       ├── Firebase Auth       (authentication)
       ├── Firebase Storage    (receipt image upload)
       └── Cloud Run API  ───► Gemini Vision API
                    │
                    └── Firestore
                          ├── users/
                          ├── receipts/
                          │     └── items/
                          ├── products/
                          └── price_index/
```

## Stack

- **Backend:** Node.js + TypeScript, Express, Firebase Admin SDK, deployed to Google Cloud Run
- **Mobile:** Flutter (Dart), targeting Android and iOS
- **Database:** Firestore
- **Auth:** Firebase Auth (email/password + Google + Apple Sign-In)
- **AI:** Gemini Vision API (receipt parsing)

## Backend Commands

```bash
cd backend
npm test          # run Jest unit tests
npm run build     # compile TypeScript
npm run dev       # run with ts-node (local dev)
```

## Development Pipeline

Project-local skills in `.claude/skills/` automate the feature lifecycle.

Start any new feature with `/feature`.
Active feature state lives in `.claude/features/{slug}/`.

Phase 1 skills (active): `feature`, `feature-plan`, `feature-dev`
Phase 2 skills (pending staging): `feature-review`, `feature-deploy`
