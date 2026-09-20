#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$ROOT_DIR/Infrastructure"
BACKEND_CONFIG="${BACKEND_CONFIG:-$ROOT_DIR/backend.local.hcl}"
PLAN_FILE=""

trap '[[ -z "$PLAN_FILE" || ! -f "$PLAN_FILE" ]] || rm -f -- "$PLAN_FILE"' EXIT INT TERM

command -v terraform >/dev/null 2>&1 || {
  printf 'Error: Terraform is not installed or is not on PATH\n' >&2
  exit 1
}

[[ -f "$BACKEND_CONFIG" ]] || {
  printf 'Error: Backend configuration not found: %s\n' "$BACKEND_CONFIG" >&2
  exit 1
}

# Preserve a subscription supplied by CI/CD; otherwise use Azure CLI.
if [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  command -v az >/dev/null 2>&1 || {
    printf 'Error: Azure CLI is not installed or is not on PATH\n' >&2
    exit 1
  }

  ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv 2>/dev/null)" || {
    printf 'Error: Azure CLI is not authenticated. Run: az login\n' >&2
    exit 1
  }

  [[ -n "$ARM_SUBSCRIPTION_ID" ]] || {
    printf 'Error: Azure CLI did not return a subscription ID\n' >&2
    exit 1
  }

  export ARM_SUBSCRIPTION_ID
fi

printf 'Azure subscription: %s\n' "$ARM_SUBSCRIPTION_ID"

# Find deployment directories that contain Terraform files.
declare -a deployments=()
shopt -s nullglob
for directory in "$INFRA_DIR"/*/; do
  terraform_files=("$directory"*.tf)
  ((${#terraform_files[@]} > 0)) && deployments+=("${directory%/}")
done
shopt -u nullglob

((${#deployments[@]} > 0)) || {
  printf 'Error: No Terraform deployments found under %s\n' "$INFRA_DIR" >&2
  exit 1
}

printf '\nAvailable deployments:\n\n'
for index in "${!deployments[@]}"; do
  printf '  %d) %s\n' "$((index + 1))" "$(basename -- "${deployments[$index]}")"
done
printf '  0) Exit\n\n'

read -r -p 'Enter deployment ID: ' selection
[[ "$selection" =~ ^[0-9]+$ ]] || {
  printf 'Error: Deployment ID must be a number\n' >&2
  exit 1
}

selection=$((10#$selection))
((selection == 0)) && exit 0
((selection <= ${#deployments[@]})) || {
  printf 'Error: Invalid deployment ID\n' >&2
  exit 1
}

terraform_directory="${deployments[$((selection - 1))]}"
deployment_name="$(basename -- "$terraform_directory")"
deployment_slug="$(printf '%s' "$deployment_name" | tr '[:upper:]' '[:lower:]')"
state_key="resources/$deployment_slug/terraform.tfstate"

printf '\nDeploying: %s\n' "$deployment_name"
printf 'Directory: %s\n' "${terraform_directory#"$ROOT_DIR"/}"
printf 'State key: %s\n\n' "$state_key"

printf '[1/4] Initializing Terraform...\n'
terraform -chdir="$terraform_directory" init \
  -input=false \
  -reconfigure \
  -backend-config="$BACKEND_CONFIG" \
  -backend-config="key=$state_key"

printf '\n[2/4] Validating configuration...\n'
terraform -chdir="$terraform_directory" validate

printf '\n[3/4] Creating execution plan...\n'
printf 'Terraform will hold the state lock while it refreshes existing Azure resources.\n'
PLAN_FILE="$(mktemp "${TMPDIR:-/tmp}/terraform-plan.XXXXXX")"
rm -f -- "$PLAN_FILE"
terraform -chdir="$terraform_directory" plan \
  -input=false \
  -lock-timeout=60s \
  -out="$PLAN_FILE"

printf '\n'
read -r -p "Review the plan above. Type APPLY to continue: " confirmation
if [[ "$confirmation" != "APPLY" ]]; then
  printf 'Apply cancelled. No infrastructure changes were made.\n'
  exit 0
fi

printf '\n[4/4] Applying the approved plan...\n'
terraform -chdir="$terraform_directory" apply \
  -input=false \
  "$PLAN_FILE"

printf '\nDeployment completed: %s\n' "$deployment_name"
