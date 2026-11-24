import pytest

from eqx_mlflow.settings import (
    AuthMode,
    BudgetSourceMode,
    EqxSettings,
    EventPublisherMode,
    InvalidSettingError,
    PolicyActionsMode,
)


def test_defaults_when_nothing_is_configured():
    settings = EqxSettings.from_env({})

    assert settings == EqxSettings(
        tenancy_enabled=False,
        usage_ledger_enabled=False,
        event_publisher=EventPublisherMode.NONE,
        budget_source=BudgetSourceMode.NONE,
        policy_actions=PolicyActionsMode.NONE,
        auth_mode=AuthMode.BASIC,
        expected_replicas=1,
    )


def test_every_setting_is_read_from_the_environment():
    settings = EqxSettings.from_env({
        "EQX_TENANCY_ENABLED": "true",
        "EQX_USAGE_LEDGER_ENABLED": "true",
        "EQX_EVENT_PUBLISHER": "kinesis",
        "EQX_BUDGET_SOURCE": "cost_explorer",
        "EQX_POLICY_ACTIONS": "sqs",
        "EQX_AUTH_MODE": "equanimo",
        "EQX_EXPECTED_REPLICAS": "3",
    })

    assert settings == EqxSettings(
        tenancy_enabled=True,
        usage_ledger_enabled=True,
        event_publisher=EventPublisherMode.KINESIS,
        budget_source=BudgetSourceMode.COST_EXPLORER,
        policy_actions=PolicyActionsMode.SQS,
        auth_mode=AuthMode.EQUANIMO,
        expected_replicas=3,
    )


@pytest.mark.parametrize(("raw", "expected"), [("true", True), ("TRUE", True), (" 1 ", True)])
def test_truthy_boolean_spellings(raw, expected):
    assert EqxSettings.from_env({"EQX_TENANCY_ENABLED": raw}).tenancy_enabled is expected


@pytest.mark.parametrize("raw", ["false", "False", "0", ""])
def test_falsy_boolean_spellings(raw):
    assert EqxSettings.from_env({"EQX_TENANCY_ENABLED": raw}).tenancy_enabled is False


def test_enum_values_are_case_insensitive():
    settings = EqxSettings.from_env({"EQX_BUDGET_SOURCE": " FILE ", "EQX_AUTH_MODE": "Equanimo"})

    assert settings.budget_source is BudgetSourceMode.FILE
    assert settings.auth_mode is AuthMode.EQUANIMO


@pytest.mark.parametrize(
    ("name", "value"),
    [
        ("EQX_TENANCY_ENABLED", "maybe"),
        ("EQX_EVENT_PUBLISHER", "kafka"),
        ("EQX_BUDGET_SOURCE", "database"),
        ("EQX_POLICY_ACTIONS", "http"),
        ("EQX_AUTH_MODE", "oauth"),
    ],
)
def test_unknown_values_are_rejected_and_name_the_setting(name, value):
    with pytest.raises(InvalidSettingError, match=name):
        EqxSettings.from_env({name: value})


def test_unknown_enum_value_lists_the_allowed_values():
    with pytest.raises(InvalidSettingError, match="none, log, kinesis"):
        EqxSettings.from_env({"EQX_EVENT_PUBLISHER": "kafka"})


@pytest.mark.parametrize("value", ["0", "-1", "two", "1.5"])
def test_expected_replicas_must_be_a_positive_integer(value):
    with pytest.raises(InvalidSettingError, match="EQX_EXPECTED_REPLICAS"):
        EqxSettings.from_env({"EQX_EXPECTED_REPLICAS": value})


@pytest.mark.parametrize("publisher", ["log", "kinesis"])
def test_publishing_events_requires_the_usage_ledger(publisher):
    with pytest.raises(InvalidSettingError, match="EQX_USAGE_LEDGER_ENABLED"):
        EqxSettings.from_env({"EQX_EVENT_PUBLISHER": publisher})


def test_publishing_events_is_allowed_with_the_usage_ledger():
    settings = EqxSettings.from_env({
        "EQX_EVENT_PUBLISHER": "kinesis",
        "EQX_USAGE_LEDGER_ENABLED": "true",
    })

    assert settings.event_publisher is EventPublisherMode.KINESIS
