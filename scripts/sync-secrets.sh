#!/usr/bin/env bash
# =============================================================================
# sync-secrets.sh — 1-Click Secrets Sync for evrry Backend
# Company: Elifsi Technologies Private Limited
#
# Reads .env.local from the project root and sets all backend secrets
# in Supabase Edge Functions with a single command.
# =============================================================================

set -e

ENV_FILE=".env.local"

if [ ! -f "$ENV_FILE" ]; then
  if [ -f ".env" ]; then
    ENV_FILE=".env"
  else
    echo "❌ Error: Neither .env.local nor .env found in root directory."
    echo "💡 Copy .env.example to .env.local, add your keys, and run this script again."
    exit 1
  fi
fi

echo "🔄 Loading secrets from $ENV_FILE..."

# List of server-side secrets to upload to Supabase
SECRETS_TO_SYNC=(
  "SUPABASE_SERVICE_ROLE_KEY"
  "OPENROUTER_API_KEY"
  "GEMINI_API_KEY"
  "ANTHROPIC_API_KEY"
  "WHATSAPP_ACCESS_TOKEN"
  "WHATSAPP_PHONE_NUMBER_ID"
  "WHATSAPP_TEMPLATE_NAME"
  "WHATSAPP_LANGUAGE_CODE"
  "SPARROW_SMS_TOKEN"
  "SPARROW_SMS_FROM"
  "AAKASH_SMS_AUTH_TOKEN"
  "ESEWA_MERCHANT_CODE"
  "ESEWA_SECRET_KEY"
  "KHALTI_PUBLIC_KEY"
  "KHALTI_SECRET_KEY"
  "CONNECTIPS_MERCHANT_ID"
  "CONNECTIPS_APP_ID"
  "CONNECTIPS_APP_PASSWORD"
  "FONEPAY_MERCHANT_CODE"
  "FONEPAY_SECRET_KEY"
  "RESEND_API_KEY"
  "RESEND_FROM_EMAIL"
  "FCM_SERVICE_ACCOUNT_KEY"
  "FCM_PROJECT_ID"
  "LIVEKIT_URL"
  "LIVEKIT_API_KEY"
  "LIVEKIT_API_SECRET"
)

ARGS=()

for SECRET in "${SECRETS_TO_SYNC[@]}"; do
  # Extract value from env file (handling optional quotes)
  VALUE=$(grep -E "^${SECRET}=" "$ENV_FILE" | cut -d '=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
  if [ -n "$VALUE" ]; then
    ARGS+=("${SECRET}=${VALUE}")
    echo "  ✅ Loaded: $SECRET"
  fi
done

if [ ${#ARGS[@]} -eq 0 ]; then
  echo "⚠️  No backend secrets found with values in $ENV_FILE."
  exit 0
fi

echo "🚀 Syncing ${#ARGS[@]} secrets to Supabase Edge Functions..."
supabase secrets set "${ARGS[@]}"

echo "✨ All secrets synced successfully to Supabase!"
