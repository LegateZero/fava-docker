#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"

SRC_DIR="${SRC_DIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd)}"
DOCKERFILE="${DOCKERFILE:-${SRC_DIR}/Dockerfile}"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-}"
HARBOR_PROJECT="${HARBOR_PROJECT:-}"
IMAGE_NAME="${IMAGE_NAME:-beancount-container}"
VERSION_TAG="${VERSION_TAG:-}"
ADDITIONAL_TAGS="${ADDITIONAL_TAGS:-}"
PUSH_IMAGE="${PUSH_IMAGE:-false}"
HARBOR_USERNAME="${HARBOR_USERNAME:-}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
SKIP_FETCH_SOURCES="${SKIP_FETCH_SOURCES:-false}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

require() {
  command -v "$1" >/dev/null || { echo "$1 is required." >&2; exit 1; }
}

require docker
require git

if [[ -z "${VERSION_TAG}" ]]; then
  VERSION_TAG="$(git -C "${SRC_DIR}" describe --tags --always --dirty 2>/dev/null || true)"
fi

VERSION_TAG="${VERSION_TAG:-dev}"
VCS_REF="$(git -C "${SRC_DIR}" rev-parse --short=12 HEAD 2>/dev/null || true)"
VCS_REF="${VCS_REF:-unknown}"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "${PUSH_IMAGE}" == "true" && -z "${HARBOR_REGISTRY}" ]]; then
  echo "HARBOR_REGISTRY is required when PUSH_IMAGE=true." >&2
  exit 1
fi

REGISTRY="${HARBOR_REGISTRY%/}"
PROJECT="${HARBOR_PROJECT#/}"
PROJECT="${PROJECT%/}"
IMAGE="${IMAGE_NAME#/}"
IMAGE="${IMAGE%/}"

if [[ -z "${REGISTRY}" ]]; then
  FULL_IMAGE_NAME="${IMAGE}"
elif [[ -n "${PROJECT}" ]]; then
  FULL_IMAGE_NAME="${REGISTRY}/${PROJECT}/${IMAGE}"
else
  FULL_IMAGE_NAME="${REGISTRY}/${IMAGE}"
fi

PRIMARY_TAG="${FULL_IMAGE_NAME}:${VERSION_TAG}"

if [[ "${SKIP_FETCH_SOURCES}" != "true" ]]; then
  log "Fetching source repositories"
  VENDOR_DIR="${SRC_DIR}/vendor" bash "${SCRIPT_DIR}/fetch-sources.sh"
fi

log "Building container ${PRIMARY_TAG}"
docker build \
  --pull \
  --tag "${PRIMARY_TAG}" \
  --build-arg "VERSION=${VERSION_TAG}" \
  --build-arg "VCS_REF=${VCS_REF}" \
  --build-arg "BUILD_DATE=${BUILD_DATE}" \
  --file "${DOCKERFILE}" \
  "${SRC_DIR}"

for tag in ${ADDITIONAL_TAGS}; do
  if [[ -n "${tag}" && "${tag}" != "${VERSION_TAG}" ]]; then
    EXTRA_TAG="${FULL_IMAGE_NAME}:${tag}"
    log "Tagging ${EXTRA_TAG}"
    docker tag "${PRIMARY_TAG}" "${EXTRA_TAG}"
  fi
done

if [[ "${PUSH_IMAGE}" == "true" ]]; then
  if [[ -n "${HARBOR_USERNAME}" && -n "${HARBOR_PASSWORD}" ]]; then
    log "Logging in to ${REGISTRY}"
    printf '%s' "${HARBOR_PASSWORD}" | docker login "${REGISTRY}" --username "${HARBOR_USERNAME}" --password-stdin
  fi

  log "Pushing ${PRIMARY_TAG}"
  docker push "${PRIMARY_TAG}"

  for tag in ${ADDITIONAL_TAGS}; do
    if [[ -n "${tag}" && "${tag}" != "${VERSION_TAG}" ]]; then
      EXTRA_TAG="${FULL_IMAGE_NAME}:${tag}"
      log "Pushing ${EXTRA_TAG}"
      docker push "${EXTRA_TAG}"
    fi
  done
fi
