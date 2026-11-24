#!/bin/sh
set -eu
: "${MLFLOW_BACKEND_STORE_URI:?}"
: "${MLFLOW_ARTIFACT_ROOT:?}"
case "${1:-serve}" in
  migrate) exec mlflow db upgrade "$MLFLOW_BACKEND_STORE_URI" ;;
  serve)
    : "${MLFLOW_CRYPTO_KEK_PASSPHRASE:?}"
    exec mlflow server \
      --host 0.0.0.0 --port 5000 \
      --backend-store-uri "$MLFLOW_BACKEND_STORE_URI" \
      --default-artifact-root "$MLFLOW_ARTIFACT_ROOT" \
      --workers 2
    ;;
  *) exec "$@" ;;
esac
