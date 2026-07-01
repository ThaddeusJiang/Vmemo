# syntax=docker/dockerfile:1.6
FROM elixir:1.19.5-otp-28 AS base
FROM node:24.14.1-bookworm-slim AS node

FROM base AS builder

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates git && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

ENV MIX_ENV=prod
ENV HEX_HTTP_TIMEOUT=120
ENV HEX_HTTP_CONCURRENCY=1
ENV HEX_HTTP_RETRIES=3

COPY mix.exs mix.lock ./
COPY assets/package.json assets/package-lock.json ./assets/
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    npm ci --prefix assets

COPY config ./config
COPY lib ./lib
COPY priv ./priv
RUN mix compile

COPY assets ./assets
RUN mix assets.deploy

COPY rel ./rel
RUN mix release

# ------------------ runner (Release runtime) ------------------
FROM base AS runner

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates imagemagick nginx && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/vmemo /app

COPY config/nginx/prod.conf /etc/nginx/nginx.conf.template
COPY rel/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV HOME=/app
ENV VMEMO_ENABLE_NGINX=true
ENV VMEMO_STORAGE_DIR=/data/storage
ENV PHX_PORT=4001

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start"]
