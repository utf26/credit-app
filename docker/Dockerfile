ARG ELIXIR_IMAGE=elixir:otp-28
FROM ${ELIXIR_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl ca-certificates \
    wkhtmltopdf fonts-dejavu fonts-liberation \
    watchman \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=dev LANG=C.UTF-8
WORKDIR /app

# Cache deps
COPY mix.exs mix.lock ./
COPY config config
RUN mix local.hex --force && mix local.rebar --force && mix deps.get

# App sources (bind-mounted in dev for hot reload)
COPY lib lib
COPY priv priv

# Copy entrypoint OUTSIDE /app so bind mount can't shadow it
COPY docker/entrypoint.sh /usr/local/bin/credit-entrypoint
RUN chmod +x /usr/local/bin/credit-entrypoint

ENV PHX_SERVER=true PORT=4000
EXPOSE 4000
CMD ["/usr/local/bin/credit-entrypoint", "mix", "phx.server"]