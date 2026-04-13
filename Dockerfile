# syntax=docker/dockerfile:1.7

ARG DEBIAN_SUITE=bookworm
ARG NODE_VERSION=25.9.0
ARG PYTHON_VERSION=3.13.13
ARG VERSION=dev
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown

FROM node:${NODE_VERSION}-${DEBIAN_SUITE} AS frontend-build

WORKDIR /src

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends make python3-babel \
 && rm -rf /var/lib/apt/lists/*

COPY vendor/fava/ /src/fava/
COPY vendor/fava-git/ /src/fava-git/

WORKDIR /src/fava
RUN make all \
 && make mostlyclean

WORKDIR /src/fava-git/frontend
RUN --mount=type=cache,target=/root/.npm \
    if [ -f package-lock.json ]; then npm ci; else npm install; fi \
 && npm run build

FROM python:${PYTHON_VERSION}-${DEBIAN_SUITE} AS python-build

ENV VIRTUAL_ENV=/app \
    PATH="/app/bin:${PATH}" \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv "${VIRTUAL_ENV}" \
 && pip install --upgrade pip setuptools wheel

COPY --from=frontend-build /src/fava/ /tmp/fava/
COPY --from=frontend-build /src/fava-git/ /tmp/fava-git/
COPY vendor/beancount/ /tmp/beancount/
COPY vendor/beanprice/ /tmp/beanprice/
COPY vendor/fava-budget-freedom/ /tmp/fava-budget-freedom/
COPY vendor/fava-currency-tracker/ /tmp/fava-currency-tracker/
COPY requirements.txt /tmp/requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        /tmp/beancount \
        /tmp/fava \
        /tmp/fava-git \
        /tmp/beanprice \
        /tmp/fava-budget-freedom \
        /tmp/fava-currency-tracker \
 && pip install -r /tmp/requirements.txt \
 && find "${VIRTUAL_ENV}" -type d -name __pycache__ -prune -exec rm -rf {} + \
 && find "${VIRTUAL_ENV}" -type f -name '*.pyc' -delete

FROM python:${PYTHON_VERSION}-slim-${DEBIAN_SUITE} AS runtime

ARG VERSION
ARG VCS_REF
ARG BUILD_DATE

LABEL org.opencontainers.image.title="beancount-container" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV VIRTUAL_ENV=/app \
    PATH="/app/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    BEANCOUNT_FILE="" \
    BEANCOUNT_HOST="0.0.0.0"

COPY --from=python-build /app/ /app/

EXPOSE 5000
CMD ["fava"]
