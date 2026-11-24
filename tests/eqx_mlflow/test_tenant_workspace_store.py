import pytest

from eqx_mlflow.tenancy import InvalidTenantIdError
from eqx_mlflow.workspace_store import TenantWorkspaceStore
from mlflow.entities.workspace import Workspace
from mlflow.exceptions import MlflowException
from mlflow.protos.databricks_pb2 import (
    INVALID_PARAMETER_VALUE,
    RESOURCE_DOES_NOT_EXIST,
    ErrorCode,
)


@pytest.fixture
def store(db_uri, monkeypatch):
    monkeypatch.setenv("MLFLOW_ENABLE_WORKSPACES", "true")
    store = TenantWorkspaceStore(db_uri)
    try:
        yield store
    finally:
        store._engine.dispose()


def _workspace_names(store):
    return [ws.name for ws in store.list_workspaces()]


def test_ensure_tenant_workspace_creates_workspace_for_new_tenant(store):
    workspace = store.ensure_tenant_workspace("t_acme")

    assert workspace.name == "t-acme"
    assert store.get_workspace("t-acme") == workspace


def test_ensure_tenant_workspace_is_idempotent(store):
    first = store.ensure_tenant_workspace("t_acme")
    second = store.ensure_tenant_workspace("t_acme")

    assert first == second
    assert _workspace_names(store).count("t-acme") == 1


def test_ensure_tenant_workspace_tolerates_workspace_created_by_another_replica(store, monkeypatch):
    store.create_workspace(Workspace(name="t-acme"))
    real_get_workspace = store.get_workspace
    calls = []

    def get_workspace_missing_on_first_call(name):
        calls.append(name)
        if len(calls) == 1:
            raise MlflowException("not found yet", RESOURCE_DOES_NOT_EXIST)
        return real_get_workspace(name)

    monkeypatch.setattr(store, "get_workspace", get_workspace_missing_on_first_call)

    workspace = store.ensure_tenant_workspace("t_acme")

    assert workspace.name == "t-acme"
    assert calls == ["t-acme", "t-acme"]


def test_ensure_tenant_workspace_rejects_invalid_tenant_id_without_creating_anything(store):
    before = _workspace_names(store)

    with pytest.raises(InvalidTenantIdError, match="tenant"):
        store.ensure_tenant_workspace("acme")

    assert _workspace_names(store) == before


def test_create_workspace_rejects_name_that_is_not_a_tenant_workspace(store):
    before = _workspace_names(store)

    with pytest.raises(MlflowException, match="tenant") as exc_info:
        store.create_workspace(Workspace(name="team-a"))

    assert exc_info.value.error_code == ErrorCode.Name(INVALID_PARAMETER_VALUE)
    assert _workspace_names(store) == before


def test_default_workspace_is_closed_to_requests_without_an_explicit_workspace(store):
    with pytest.raises(MlflowException, match="explicit workspace") as exc_info:
        store.get_default_workspace()

    assert exc_info.value.error_code == ErrorCode.Name(INVALID_PARAMETER_VALUE)
