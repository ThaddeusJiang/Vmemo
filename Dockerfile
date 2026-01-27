FROM elixir:1.19.2-otp-28 AS base

FROM base as builder

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates git rustc cargo pkg-config \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix do local.hex --force && \
    mix local.rebar --force
RUN mix deps.get --only prod

ENV MIX_ENV=prod

COPY . .
RUN mix deps.get
RUN mix compile
RUN mix assets.deploy

# ------------------ runner ------------------
FROM base AS runner

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses6 libtinfo6 locales ca-certificates git \
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

CMD ["mix", "phx.server"]
