#!/usr/bin/env bash
set -euo pipefail

VENDOR_DIR="${VENDOR_DIR:-vendor}"
FAVA_VERSION="${FAVA_VERSION:-v1.30.12}"
BEANCOUNT_VERSION="${BEANCOUNT_VERSION:-3.2.0}"
FAVA_GIT_REF="${FAVA_GIT_REF:-main}"
BEANPRICE_REF="${BEANPRICE_REF:-HEAD}"
FAVA_BUDGET_FREEDOM_REF="${FAVA_BUDGET_FREEDOM_REF:-HEAD}"
FAVA_CURRENCY_TRACKER_REF="${FAVA_CURRENCY_TRACKER_REF:-HEAD}"
REFRESH="${REFRESH:-false}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

case "${VENDOR_DIR}" in
  /*) RESOLVED_VENDOR_DIR="${VENDOR_DIR}" ;;
  *) RESOLVED_VENDOR_DIR="${REPO_ROOT}/${VENDOR_DIR}" ;;
esac

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

origin_head() {
  local path="$1"

  if ! git -C "${path}" symbolic-ref --short refs/remotes/origin/HEAD >/dev/null 2>&1; then
    git -C "${path}" remote set-head origin --auto >/dev/null
  fi

  git -C "${path}" symbolic-ref --short refs/remotes/origin/HEAD
}

sync_repo() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local target="${RESOLVED_VENDOR_DIR}/${name}"

  case "${target}" in
    "${RESOLVED_VENDOR_DIR}"/*) ;;
    *) echo "Refusing to write outside vendor directory: ${target}" >&2; exit 1 ;;
  esac

  if [[ "${REFRESH}" == "true" && -e "${target}" ]]; then
    rm -rf -- "${target}"
  fi

  if [[ -d "${target}" ]]; then
    if [[ ! -d "${target}/.git" ]]; then
      echo "${target} exists, but is not a git repository. Remove it or run with REFRESH=true." >&2
      exit 1
    fi

    log "Updating ${name} (${ref})"
    git -C "${target}" fetch --tags --prune origin
  else
    log "Cloning ${name} (${ref})"
    git clone --filter=blob:none "${url}" "${target}"
    git -C "${target}" fetch --tags --prune origin
  fi

  if [[ "${ref}" == "HEAD" ]]; then
    git -C "${target}" checkout --force --detach "$(origin_head "${target}")"
  else
    git -C "${target}" checkout --force "${ref}"
  fi

  git -C "${target}" submodule update --init --recursive
}

command -v git >/dev/null || { echo "git is required to fetch source repositories." >&2; exit 1; }

mkdir -p -- "${RESOLVED_VENDOR_DIR}"

sync_repo "fava" "https://github.com/beancount/fava.git" "${FAVA_VERSION}"
sync_repo "fava-git" "https://github.com/Evernight/fava-git.git" "${FAVA_GIT_REF}"
sync_repo "beancount" "https://github.com/beancount/beancount.git" "${BEANCOUNT_VERSION}"
sync_repo "beanprice" "https://github.com/beancount/beanprice.git" "${BEANPRICE_REF}"
sync_repo "fava-budget-freedom" "https://github.com/Leon2xiaowu/fava_budget_freedom.git" "${FAVA_BUDGET_FREEDOM_REF}"
sync_repo "fava-currency-tracker" "https://github.com/Evernight/fava-currency-tracker.git" "${FAVA_CURRENCY_TRACKER_REF}"

log "Sources are ready in ${RESOLVED_VENDOR_DIR}"
