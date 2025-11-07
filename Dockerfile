FROM elixir:1.19.2 AS builder

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses5 locales ca-certificates git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix do local.hex --force, local.rebar --force, deps.get --only prod

ENV MIX_ENV="prod"

COPY . .
RUN mix deps.get
RUN mix compile
RUN mix assets.deploy

# ------------------ runner ------------------
FROM elixir:1.19.2 AS runner

RUN apt-get update -y && \
  apt-get install -y build-essential libstdc++6 openssl libncurses5 locales ca-certificates git \
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

# 启动 Phoenix 服务器
CMD ["mix", "phx.server"]
