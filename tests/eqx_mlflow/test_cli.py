import pytest
from click.testing import CliRunner

from eqx_mlflow import cli as eqx_cli
from eqx_mlflow.workspace_store import TenantWorkspaceStore
from mlflow.exceptions import MlflowException

STRONG_KEK = "correct-horse-battery-staple-9f3a"
SAFE_ENV = {"MLFLOW_CRYPTO_KEK_PASSPHRASE": STRONG_KEK}
TENANT_ENV = {
    **SAFE_ENV,
    "EQX_TENANCY_ENABLED": "true",
    "MLFLOW_ENABLE_WORKSPACES": "true",
    "MLFLOW_WORKSPACE_STORE_URI": "eqx+postgresql://mlflow@db.internal/mlflow",
}


@pytest.fixture
def launched(monkeypatch):
    calls = []
    monkeypatch.setattr(eqx_cli, "_run_mlflow_server", calls.append)
    return calls


def _invoke(args, env):
    return CliRunner().invoke(eqx_cli.cli, args, env=env)


def test_server_refuses_to_start_with_an_unsafe_configuration(launched):
    result = _invoke(["server"], env={"MLFLOW_CRYPTO_KEK_PASSPHRASE": ""})

    assert result.exit_code != 0
    assert "MLFLOW_CRYPTO_KEK_PASSPHRASE" in result.output
    assert launched == []


def test_server_refuses_to_start_with_an_invalid_eqx_setting(launched):
    result = _invoke(["server"], env={**SAFE_ENV, "EQX_EVENT_PUBLISHER": "kafka"})

    assert result.exit_code != 0
    assert "EQX_EVENT_PUBLISHER" in result.output
    assert launched == []


def test_server_passes_its_arguments_through_to_mlflow_when_configuration_is_safe(launched):
    result = _invoke(["server", "--host", "0.0.0.0", "--port", "5001"], env=SAFE_ENV)

    assert result.exit_code == 0, result.output
    assert launched == [["--host", "0.0.0.0", "--port", "5001"]]


@pytest.mark.parametrize(
    "args",
    [
        ["server"],
        ["server", "--port", "5001"],
        ["server", "--app-name", "other"],
        ["server", "--app-name=other"],
    ],
)
def test_tenancy_requires_the_basic_auth_app(args, launched):
    result = _invoke(args, env=TENANT_ENV)

    assert result.exit_code != 0
    assert "basic-auth" in result.output
    assert launched == []


@pytest.mark.parametrize(
    "args",
    [
        ["server", "--app-name", "basic-auth"],
        ["server", "--app-name=basic-auth", "--port", "5001"],
    ],
)
def test_tenancy_with_the_basic_auth_app_starts(args, launched):
    result = _invoke(args, env=TENANT_ENV)

    assert result.exit_code == 0, result.output
    assert launched == [args[1:]]


@pytest.fixture
def tenant_store_env(db_uri, monkeypatch):
    monkeypatch.setenv("MLFLOW_ENABLE_WORKSPACES", "true")
    return {"MLFLOW_WORKSPACE_STORE_URI": f"eqx+{db_uri}"}


def _workspace_names(db_uri):
    store = TenantWorkspaceStore(db_uri)
    try:
        return {ws.name for ws in store.list_workspaces()}
    finally:
        store._engine.dispose()


def test_tenants_create_provisions_the_tenant_workspace(db_uri, tenant_store_env):
    result = _invoke(["tenants", "create", "t_acme"], env=tenant_store_env)

    assert result.exit_code == 0, result.output
    assert "t-acme" in result.output
    assert "t-acme" in _workspace_names(db_uri)


def test_tenants_create_accepts_the_store_uri_as_an_option(db_uri, monkeypatch):
    monkeypatch.setenv("MLFLOW_ENABLE_WORKSPACES", "true")

    result = _invoke(["tenants", "create", "t_acme", "--workspace-store-uri", f"eqx+{db_uri}"], {})

    assert result.exit_code == 0, result.output
    assert "t-acme" in _workspace_names(db_uri)


def test_tenants_create_is_idempotent(db_uri, tenant_store_env):
    first = _invoke(["tenants", "create", "t_acme"], env=tenant_store_env)
    second = _invoke(["tenants", "create", "t_acme"], env=tenant_store_env)

    assert first.exit_code == 0, first.output
    assert second.exit_code == 0, second.output
    assert [n for n in _workspace_names(db_uri) if n == "t-acme"] == ["t-acme"]


def test_tenants_create_rejects_an_invalid_tenant_id(db_uri, tenant_store_env):
    before = _workspace_names(db_uri)

    result = _invoke(["tenants", "create", "acme"], env=tenant_store_env)

    assert result.exit_code != 0
    assert "tenant" in result.output
    assert _workspace_names(db_uri) == before


def test_tenants_create_requires_the_workspace_store_uri():
    result = _invoke(["tenants", "create", "t_acme"], env={"MLFLOW_WORKSPACE_STORE_URI": ""})

    assert result.exit_code != 0
    assert "MLFLOW_WORKSPACE_STORE_URI" in result.output


def test_tenants_create_reports_a_store_that_is_not_the_tenant_store(db_uri):
    result = _invoke(["tenants", "create", "t_acme", "--workspace-store-uri", db_uri], env={})

    assert result.exit_code != 0
    assert "eqx+" in result.output


def test_mlflow_errors_from_the_store_are_reported_without_a_traceback(
    db_uri, tenant_store_env, monkeypatch
):
    def fail(self, tenant_id):
        raise MlflowException("database is unavailable")

    monkeypatch.setattr(TenantWorkspaceStore, "ensure_tenant_workspace", fail)

    result = _invoke(["tenants", "create", "t_acme"], env=tenant_store_env)

    assert result.exit_code != 0
    assert "database is unavailable" in result.output
    assert "Traceback" not in result.output
