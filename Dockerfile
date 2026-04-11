FROM node:25.9.0-bookworm AS build

ARG FAVA_VERSION=v1.30.12
ARG BEANCOUNT_VERSION=3.2.0

WORKDIR /tmp
RUN git clone https://github.com/beancount/fava.git fava

WORKDIR /tmp/fava

RUN apt update && apt install python3-babel -y
RUN git checkout ${FAVA_VERSION}
RUN make all
RUN make mostlyclean

WORKDIR /tmp
RUN git clone -b main https://github.com/Evernight/fava-git.git fava-git
WORKDIR /tmp/fava-git/frontend
RUN  npm install && npm run build

FROM python:3.13.13-bookworm AS build_bc

COPY --from=build /tmp/fava /tmp/fava
COPY --from=build /tmp/fava-git /tmp/fava-git

ENV PATH="/app/bin:${PATH}"
RUN python3 -m venv /app
RUN /app/bin/pip install --no-cache-dir -U /tmp/fava
RUN /app/bin/pip install --no-cache-dir -U /tmp/fava-git

WORKDIR /tmp
RUN git clone https://github.com/beancount/beancount.git beancount
WORKDIR /tmp/beancount
RUN /app/bin/pip install --no-cache-dir -U .

WORKDIR /
COPY requirements.txt requirements.txt
RUN /app/bin/pip install -r requirements.txt

RUN find /app -type d -name __pycache__ -prune -exec rm -rf {} + \
 && find /app -type f -name '*.pyc' -delete

FROM python:3.13.13-slim-bookworm
COPY --from=build_bc /app /app
ENV PATH="/app/bin:${PATH}"

ENV BEANCOUNT_FILE=""
ENV BEANCOUNT_HOST="0.0.0.0"
CMD ["fava"]