# syntax=docker/dockerfile:1.6
FROM elixir:1.19.5-otp-28 AS base

FROM base as builder

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod
ENV HEX_HTTP_TIMEOUT=120
ENV HEX_HTTP_CONCURRENCY=1
ENV HEX_HTTP_RETRIES=3

COPY mix.exs mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod

COPY . .
RUN mix compile
RUN mix assets.deploy

# ------------------ runner (Elixir image + Mix) ------------------
FROM base AS runner

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses5 locales ca-certificates git postgresql-client \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && \
  mix local.rebar --force

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
COPY --from=builder /app ./

# Copy entrypoint script
COPY rel/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV MIX_ENV=prod

# Use entrypoint script to handle migrations before starting server
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mix", "phx.server"]
