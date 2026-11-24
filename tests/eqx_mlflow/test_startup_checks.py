import pytest

from eqx_mlflow.settings import EqxSettings
from eqx_mlflow.startup_checks import StartupCheckError, check_startup
from mlflow.utils.crypto import DEFAULT_KEK_PASSPHRASE

KEK = "MLFLOW_CRYPTO_KEK_PASSPHRASE"
REDIS = "MLFLOW_GATEWAY_BUDGET_REDIS_URL"
STRONG_KEK = "correct-horse-battery-staple-9f3a"


def test_valid_single_replica_configuration_passes():
    check_startup(EqxSettings(), {KEK: STRONG_KEK})


@pytest.mark.parametrize("env", [{}, {KEK: ""}, {KEK: "   "}])
def test_missing_or_blank_kek_passphrase_is_rejected(env):
    with pytest.raises(StartupCheckError, match=KEK):
        check_startup(EqxSettings(), env)


def test_the_development_default_kek_passphrase_is_rejected():
    with pytest.raises(StartupCheckError, match="development default"):
        check_startup(EqxSettings(), {KEK: DEFAULT_KEK_PASSPHRASE})


def test_multiple_replicas_without_redis_are_rejected():
    with pytest.raises(StartupCheckError, match=REDIS):
        check_startup(EqxSettings(expected_replicas=2), {KEK: STRONG_KEK})


@pytest.mark.parametrize("redis_url", ["", "  "])
def test_blank_redis_url_counts_as_missing(redis_url):
    with pytest.raises(StartupCheckError, match=REDIS):
        check_startup(EqxSettings(expected_replicas=2), {KEK: STRONG_KEK, REDIS: redis_url})


def test_multiple_replicas_with_redis_pass():
    check_startup(
        EqxSettings(expected_replicas=3),
        {KEK: STRONG_KEK, REDIS: "redis://redis.internal:6379/0"},
    )


def test_all_problems_are_reported_together():
    with pytest.raises(StartupCheckError, match="Refusing to start") as exc_info:
        check_startup(EqxSettings(expected_replicas=2), {})

    message = str(exc_info.value)
    assert KEK in message
    assert REDIS in message


WORKSPACES = "MLFLOW_ENABLE_WORKSPACES"
WORKSPACE_STORE = "MLFLOW_WORKSPACE_STORE_URI"
TENANT_ENV = {
    KEK: STRONG_KEK,
    WORKSPACES: "true",
    WORKSPACE_STORE: "eqx+postgresql://mlflow@db.internal/mlflow",
}


def test_tenancy_configuration_passes_when_workspaces_and_tenant_store_are_set():
    check_startup(EqxSettings(tenancy_enabled=True), TENANT_ENV)


@pytest.mark.parametrize("value", [None, "", "false"])
def test_tenancy_requires_workspaces_to_be_enabled(value):
    env = {**TENANT_ENV, WORKSPACES: value}
    if value is None:
        del env[WORKSPACES]

    with pytest.raises(StartupCheckError, match=WORKSPACES):
        check_startup(EqxSettings(tenancy_enabled=True), env)


@pytest.mark.parametrize(
    "uri", [None, "", "postgresql://mlflow@db.internal/mlflow", "http://workspaces.internal"]
)
def test_tenancy_requires_the_tenant_workspace_store(uri):
    env = {**TENANT_ENV, WORKSPACE_STORE: uri}
    if uri is None:
        del env[WORKSPACE_STORE]

    with pytest.raises(StartupCheckError, match=WORKSPACE_STORE):
        check_startup(EqxSettings(tenancy_enabled=True), env)


def test_workspace_settings_are_not_required_when_tenancy_is_disabled():
    check_startup(EqxSettings(tenancy_enabled=False), {KEK: STRONG_KEK})
