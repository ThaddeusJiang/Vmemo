# syntax=docker/dockerfile:1.6
FROM elixir:1.19.2-otp-28 AS base

FROM base as builder

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN --mount=type=cache,target=/root/.hex \
    --mount=type=cache,target=/root/.mix \
    --mount=type=cache,target=/app/deps \
    mix do local.hex --force, local.rebar --force, deps.get --only prod

COPY . .
RUN --mount=type=cache,target=/app/_build \
    mix compile
RUN --mount=type=cache,target=/root/.cache \
    mix assets.deploy

# ------------------ runner ------------------
FROM base AS runner

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates \
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

ENV MIX_ENV=prod

COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
