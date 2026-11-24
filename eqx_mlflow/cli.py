from __future__ import annotations

import os

import click

from eqx_mlflow.settings import EqxSettings, InvalidSettingError
from eqx_mlflow.startup_checks import StartupCheckError, check_startup
from eqx_mlflow.tenancy import InvalidTenantIdError
from eqx_mlflow.workspace_store import build_tenant_workspace_store
from mlflow.cli import cli as mlflow_cli
from mlflow.environment_variables import MLFLOW_WORKSPACE_STORE_URI
from mlflow.exceptions import MlflowException

_REQUIRED_APP_NAME = "basic-auth"


def _run_mlflow_server(args: list[str]) -> None:
    mlflow_cli.main(args=["server", *args], prog_name="mlflow")


def _app_name(args: list[str]) -> str | None:
    for i, arg in enumerate(args):
        if arg == "--app-name":
            return args[i + 1] if i + 1 < len(args) else None
        if arg.startswith("--app-name="):
            return arg.removeprefix("--app-name=")
    return None


@click.group()
def cli():
    """Operate the Equanimo MLflow AI Gateway."""


@cli.command(context_settings={"ignore_unknown_options": True})
@click.argument("mlflow_args", nargs=-1, type=click.UNPROCESSED)
def server(mlflow_args: tuple[str, ...]):
    """Check the configuration, then run `mlflow server` with MLFLOW_ARGS."""
    args = list(mlflow_args)
    try:
        settings = EqxSettings.from_env(os.environ)
        check_startup(settings, os.environ)
    except (InvalidSettingError, StartupCheckError) as e:
        raise click.ClickException(str(e)) from e

    if settings.tenancy_enabled and _app_name(args) != _REQUIRED_APP_NAME:
        raise click.ClickException(
            f"EQX_TENANCY_ENABLED is true, so the server must run with "
            f"'--app-name {_REQUIRED_APP_NAME}'. Without authentication, any caller could "
            "choose any tenant's workspace."
        )

    _run_mlflow_server(args)


@cli.group()
def tenants():
    """Manage tenant workspaces."""


@tenants.command()
@click.argument("tenant_id")
@click.option(
    "--workspace-store-uri",
    envvar=MLFLOW_WORKSPACE_STORE_URI.name,
    help="An 'eqx+<database>://' URI. Defaults to $MLFLOW_WORKSPACE_STORE_URI.",
)
def create(tenant_id: str, workspace_store_uri: str | None):
    """Create the workspace for TENANT_ID if it does not exist yet."""
    if not workspace_store_uri:
        raise click.ClickException(
            f"Provide --workspace-store-uri or set {MLFLOW_WORKSPACE_STORE_URI.name}."
        )
    try:
        store = build_tenant_workspace_store(workspace_uri=workspace_store_uri)
        try:
            workspace = store.ensure_tenant_workspace(tenant_id)
        finally:
            store._engine.dispose()
    except InvalidTenantIdError as e:
        raise click.ClickException(str(e)) from e
    except MlflowException as e:
        raise click.ClickException(e.message) from e
    click.echo(f"Tenant {tenant_id} -> workspace {workspace.name}")
