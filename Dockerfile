FROM node:25.9.0-bookworm as build

ARG FAVA_VERSION
ARG BEANCOUNT_VERSION

WORKDIR /tmp
RUN git clone -b main https://github.com/beancount/fava.git fava

WORKDIR /tmp/fava

RUN make