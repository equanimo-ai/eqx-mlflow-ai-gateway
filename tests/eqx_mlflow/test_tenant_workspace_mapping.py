import pytest

from eqx_mlflow.tenancy import (
    InvalidTenantIdError,
    tenant_id_to_workspace,
    workspace_to_tenant_id,
)
from mlflow.store.workspace.abstract_store import WorkspaceNameValidator


@pytest.mark.parametrize(
    ("tenant_id", "workspace"),
    [
        ("t_acme", "t-acme"),
        ("t_acme_corp", "t-acme-corp"),
        ("t_platform", "t-platform"),
        ("t_dev", "t-dev"),
        ("t_a1", "t-a1"),
    ],
)
def test_tenant_id_maps_to_valid_workspace_name(tenant_id, workspace):
    assert tenant_id_to_workspace(tenant_id) == workspace
    WorkspaceNameValidator.validate(workspace)


@pytest.mark.parametrize("tenant_id", ["t_acme", "t_acme_corp", "t_platform", "t_a__b"])
def test_mapping_round_trips(tenant_id):
    assert workspace_to_tenant_id(tenant_id_to_workspace(tenant_id)) == tenant_id


@pytest.mark.parametrize(
    "tenant_id",
    [
        "",
        "acme",
        "t-acme",
        "T_ACME",
        "t_Acme",
        "t_",
        "t_acme_",
        "t_acme\n",
        "t_ac me",
        "t_acme/../x",
        "org_abc123",
        "t_" + "a" * 62,
    ],
)
def test_invalid_tenant_ids_are_rejected(tenant_id):
    with pytest.raises(InvalidTenantIdError, match="tenant"):
        tenant_id_to_workspace(tenant_id)


@pytest.mark.parametrize("value", [None, 123, b"t_acme"])
def test_non_string_tenant_id_is_rejected(value):
    with pytest.raises(InvalidTenantIdError, match="tenant"):
        tenant_id_to_workspace(value)


def test_longest_valid_tenant_id_is_accepted():
    tenant_id = "t_" + "a" * 61
    assert len(tenant_id_to_workspace(tenant_id)) == 63


@pytest.mark.parametrize("workspace", [None, 123])
def test_non_string_workspace_is_rejected(workspace):
    with pytest.raises(InvalidTenantIdError, match="workspace"):
        workspace_to_tenant_id(workspace)


@pytest.mark.parametrize("workspace", ["default", "acme", "t-", "t-acme-", "t_acme", "T-ACME", ""])
def test_workspace_that_is_not_a_tenant_workspace_is_rejected(workspace):
    with pytest.raises(InvalidTenantIdError, match="workspace"):
        workspace_to_tenant_id(workspace)
