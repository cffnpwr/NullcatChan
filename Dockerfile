FROM node:16 AS module

WORKDIR /app

RUN apt-get update
RUN apt-get install -y build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev

COPY package.json .

RUN corepack enable
RUN pnpm install --prod


FROM module AS build

RUN pnpm install

COPY . .

RUN pnpm build


FROM debian:bullseye AS mecab

RUN apt-get update
RUN apt-get install -y sudo mecab libmecab-dev mecab-ipadic-utf8 git make curl xz-utils file build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev
RUN git clone --depth 1 https://github.com/neologd/mecab-ipadic-neologd.git
RUN cd mecab-ipadic-neologd
RUN ./mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -y -p /min
RUN echo "dicdir = /min" > /etc/mecabrc


FROM alpine:3 AS lib

RUN apk update
RUN apk add tini-static
RUN mv /sbin/tini-static /tini


FROM node:16-slim

ENV NODE_ENV="production"

RUN apt-get update && \
	apt-get install -y mecab && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /nullcatchan

COPY package.json .
COPY --from=module /app/node_modules node_modules
COPY --from=build /app/built built
COPY --from=mecab /min /min
COPY --from=mecab /etc/mecabrc /etc/mecabrc
COPY --from=lib /tini /tini

ENTRYPOINT ["/tini", "--"]
CMD ["node", "./built"]

