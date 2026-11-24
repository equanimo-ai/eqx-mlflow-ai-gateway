from __future__ import annotations

from collections.abc import Mapping

from eqx_mlflow.settings import EqxSettings
from eqx_mlflow.workspace_store import WORKSPACE_PROVIDER_SCHEMES
from mlflow.environment_variables import (
    MLFLOW_ENABLE_WORKSPACES,
    MLFLOW_GATEWAY_BUDGET_REDIS_URL,
    MLFLOW_WORKSPACE_STORE_URI,
)
from mlflow.utils.crypto import CRYPTO_KEK_PASSPHRASE_ENV_VAR, DEFAULT_KEK_PASSPHRASE


class StartupCheckError(RuntimeError):
    pass


def check_startup(settings: EqxSettings, env: Mapping[str, str]) -> None:
    """Refuse to start with a configuration that is unsafe for a shared deployment."""
    problems = []

    kek_passphrase = env.get(CRYPTO_KEK_PASSPHRASE_ENV_VAR, "").strip()
    if not kek_passphrase:
        problems.append(
            f"{CRYPTO_KEK_PASSPHRASE_ENV_VAR} is not set. Provider API keys would be encrypted "
            "with a publicly known key. Set it to a unique, high-entropy secret."
        )
    elif kek_passphrase == DEFAULT_KEK_PASSPHRASE:
        problems.append(
            f"{CRYPTO_KEK_PASSPHRASE_ENV_VAR} is set to the development default. "
            "Set it to a unique, high-entropy secret."
        )

    redis_url = env.get(MLFLOW_GATEWAY_BUDGET_REDIS_URL.name, "").strip()
    if settings.expected_replicas > 1 and not redis_url:
        problems.append(
            f"{MLFLOW_GATEWAY_BUDGET_REDIS_URL.name} is not set but EQX_EXPECTED_REPLICAS is "
            f"{settings.expected_replicas}. The in-memory budget tracker counts spend per "
            "process, so budgets would be enforced against a fraction of the real spend."
        )

    if settings.tenancy_enabled:
        problems.extend(_check_tenancy(env))

    if problems:
        raise StartupCheckError(
            "Refusing to start:\n" + "\n".join(f"  - {problem}" for problem in problems)
        )


def _check_tenancy(env: Mapping[str, str]) -> list[str]:
    problems = []

    if env.get(MLFLOW_ENABLE_WORKSPACES.name, "").strip().lower() not in {"true", "1"}:
        problems.append(
            f"EQX_TENANCY_ENABLED is true but {MLFLOW_ENABLE_WORKSPACES.name} is not. Without "
            "workspaces, every tenant would share one set of endpoints, secrets and budgets."
        )

    workspace_store_uri = env.get(MLFLOW_WORKSPACE_STORE_URI.name, "").strip()
    if workspace_store_uri.split("://", 1)[0] not in WORKSPACE_PROVIDER_SCHEMES:
        problems.append(
            f"EQX_TENANCY_ENABLED is true but {MLFLOW_WORKSPACE_STORE_URI.name} is not an "
            "'eqx+<database>://' URI, so MLflow would use its default workspace store instead "
            "of the Equanimo tenant workspace store."
        )

    return problems
