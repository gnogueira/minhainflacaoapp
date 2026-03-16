#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup-gcp.sh — one-time GCP setup for Minha Inflação backend
#
# Run this once before the first deploy:
#   chmod +x backend/scripts/setup-gcp.sh
#   ./backend/scripts/setup-gcp.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:-minhainflacaoapp}"
REGION="${GCP_REGION:-us-east1}"
SERVICE_NAME="minha-inflacao-api"
GITHUB_REPO="${GITHUB_REPO:-}"   # e.g. "octocat/minha-inflacao" — for WIF setup

# ── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo "▶ $*"; }
success() { echo "✓ $*"; }

# ── 1. Set active project ─────────────────────────────────────────────────────
info "Setting active project to $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# ── 2. Enable required APIs ───────────────────────────────────────────────────
info "Enabling required GCP APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com
success "APIs enabled"

# ── 3. Store GEMINI_API_KEY in Secret Manager ─────────────────────────────────
if gcloud secrets describe GEMINI_API_KEY --project="$PROJECT_ID" &>/dev/null; then
  info "Secret GEMINI_API_KEY already exists — skipping creation"
else
  info "Creating GEMINI_API_KEY secret..."
  read -rsp "Paste your Gemini API key: " GEMINI_KEY
  echo
  echo -n "$GEMINI_KEY" | gcloud secrets create GEMINI_API_KEY \
    --project="$PROJECT_ID" \
    --replication-policy="automatic" \
    --data-file=-
  success "Secret GEMINI_API_KEY created"
fi

# ── 4. Grant Cloud Run SA access to Firebase/GCP resources ───────────────────
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CLOUD_RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

info "Granting roles to Cloud Run service account ($CLOUD_RUN_SA)..."

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_RUN_SA" \
  --role="roles/datastore.user" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_RUN_SA" \
  --role="roles/storage.objectAdmin" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_RUN_SA" \
  --role="roles/firebase.sdkAdminServiceAgent" --quiet

gcloud secrets add-iam-policy-binding GEMINI_API_KEY \
  --project="$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_RUN_SA" \
  --role="roles/secretmanager.secretAccessor" --quiet

success "IAM roles granted"

# ── 5. Workload Identity Federation for GitHub Actions (optional) ─────────────
if [[ -n "$GITHUB_REPO" ]]; then
  info "Setting up Workload Identity Federation for GitHub repo: $GITHUB_REPO"

  POOL_ID="github-actions-pool"
  PROVIDER_ID="github-provider"
  WIF_SA="github-actions-deploy@${PROJECT_ID}.iam.gserviceaccount.com"

  # Create service account for GitHub Actions
  if ! gcloud iam service-accounts describe "$WIF_SA" --project="$PROJECT_ID" &>/dev/null; then
    gcloud iam service-accounts create github-actions-deploy \
      --project="$PROJECT_ID" \
      --display-name="GitHub Actions Deploy"
  fi

  # Grant deploy permissions
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$WIF_SA" \
    --role="roles/run.admin" --quiet

  gcloud iam service-accounts add-iam-policy-binding "$CLOUD_RUN_SA" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:$WIF_SA" \
    --role="roles/iam.serviceAccountUser" --quiet

  # Create WIF pool
  if ! gcloud iam workload-identity-pools describe "$POOL_ID" \
      --project="$PROJECT_ID" --location="global" &>/dev/null; then
    gcloud iam workload-identity-pools create "$POOL_ID" \
      --project="$PROJECT_ID" \
      --location="global" \
      --display-name="GitHub Actions Pool"
  fi

  # Create WIF provider
  if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
      --project="$PROJECT_ID" \
      --location="global" \
      --workload-identity-pool="$POOL_ID" &>/dev/null; then
    gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
      --project="$PROJECT_ID" \
      --location="global" \
      --workload-identity-pool="$POOL_ID" \
      --issuer-uri="https://token.actions.githubusercontent.com" \
      --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
      --attribute-condition="assertion.repository=='${GITHUB_REPO}'"
  fi

  # Allow GitHub repo to impersonate the SA
  POOL_RESOURCE="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}"
  gcloud iam service-accounts add-iam-policy-binding "$WIF_SA" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${POOL_RESOURCE}/attribute.repository/${GITHUB_REPO}" \
    --quiet

  WIF_PROVIDER="${POOL_RESOURCE}/providers/${PROVIDER_ID}"

  echo ""
  success "Workload Identity Federation configured!"
  echo ""
  echo "Add these secrets to your GitHub repository (Settings > Secrets > Actions):"
  echo ""
  echo "  GCP_PROJECT_ID         = $PROJECT_ID"
  echo "  GCP_REGION             = $REGION"
  echo "  GCP_WIF_PROVIDER       = $WIF_PROVIDER"
  echo "  GCP_WIF_SERVICE_ACCOUNT = $WIF_SA"
else
  echo ""
  info "Skipping Workload Identity Federation (GITHUB_REPO not set)"
  info "To set up GitHub Actions deploy, re-run with:"
  info "  GITHUB_REPO=owner/repo ./backend/scripts/setup-gcp.sh"
fi

echo ""
success "GCP setup complete! You can now deploy with:"
echo ""
echo "  gcloud run deploy $SERVICE_NAME \\"
echo "    --source ./backend \\"
echo "    --region $REGION \\"
echo "    --set-secrets=GEMINI_API_KEY=GEMINI_API_KEY:latest \\"
echo "    --allow-unauthenticated"
