FROM node:24-bookworm-slim AS ui
WORKDIR /src/mlflow/server/js
COPY mlflow/server/js ./
RUN node yarn/releases/yarn-4.12.0.cjs install --immutable \
    && node yarn/releases/yarn-4.12.0.cjs build

FROM python:3.11-slim-bookworm
RUN useradd --create-home --uid 10001 mlflow
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
COPY --from=ui /src/mlflow/server/js/build mlflow/server/js/build
# Built from this repo so the gateway-only UI and frame-ancestors changes ship. The root package
# pins mlflow-skinny and mlflow-tracing to the same dev version, which is not on PyPI.
RUN pip install --no-cache-dir ./libs/skinny ./libs/tracing '.[genai]' psycopg2-binary boto3
WORKDIR /
COPY docker/mlflow/entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh
USER 10001
EXPOSE 5000
ENTRYPOINT ["/entrypoint.sh"]
