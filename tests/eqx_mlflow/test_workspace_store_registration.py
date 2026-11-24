from importlib.metadata import entry_points

import pytest

from eqx_mlflow.workspace_store import (
    WORKSPACE_PROVIDER_SCHEMES,
    TenantWorkspaceStore,
    build_tenant_workspace_store,
)
from mlflow.exceptions import MlflowException
from mlflow.protos.databricks_pb2 import INVALID_PARAMETER_VALUE, ErrorCode
from mlflow.store.db.db_types import DATABASE_ENGINES
from mlflow.tracking._workspace.registry import WorkspaceStoreRegistry, get_workspace_store


@pytest.fixture
def eqx_uri(db_uri):
    assert db_uri.startswith("sqlite")
    return f"eqx+{db_uri}"


def test_builder_creates_a_tenant_store_on_the_wrapped_database(eqx_uri, db_uri):
    store = build_tenant_workspace_store(workspace_uri=eqx_uri)
    try:
        assert isinstance(store, TenantWorkspaceStore)
        assert store._workspace_uri == db_uri
    finally:
        store._engine.dispose()


@pytest.mark.parametrize("uri", ["sqlite:///x.db", "postgresql://u:p@h/db", "eqx://x", ""])
def test_builder_rejects_uris_without_the_eqx_database_scheme(uri):
    with pytest.raises(MlflowException, match="eqx") as exc_info:
        build_tenant_workspace_store(workspace_uri=uri)

    assert exc_info.value.error_code == ErrorCode.Name(INVALID_PARAMETER_VALUE)


def test_registry_resolves_eqx_uris_to_the_tenant_store(eqx_uri):
    registry = WorkspaceStoreRegistry()
    for scheme in WORKSPACE_PROVIDER_SCHEMES:
        registry.register(scheme, build_tenant_workspace_store)

    store = registry.get_store(eqx_uri)
    try:
        assert isinstance(store, TenantWorkspaceStore)
    finally:
        store._engine.dispose()


def test_there_is_one_scheme_per_database_engine_mlflow_supports():
    assert set(WORKSPACE_PROVIDER_SCHEMES) == {f"eqx+{engine}" for engine in DATABASE_ENGINES}


def test_entry_points_register_the_builder_for_every_scheme():
    registered = {ep.name: ep.value for ep in entry_points(group="mlflow.workspace_provider")}

    expected = "eqx_mlflow.workspace_store:build_tenant_workspace_store"
    assert {
        scheme: registered.get(scheme) for scheme in WORKSPACE_PROVIDER_SCHEMES
    } == dict.fromkeys(WORKSPACE_PROVIDER_SCHEMES, expected)


def test_servers_global_registry_resolves_eqx_uris_from_installed_entry_points(eqx_uri):
    store = get_workspace_store(workspace_uri=eqx_uri)
    try:
        assert isinstance(store, TenantWorkspaceStore)
    finally:
        store._engine.dispose()
