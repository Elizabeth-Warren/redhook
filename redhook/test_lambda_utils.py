# tests/lambda_utils.py

import os.path
from base64 import b64encode
from json import loads

import pytest

from . import lambda_utils
from .config import config


@pytest.fixture
def sample_json_body():
    with open(
        os.path.join(config.project_root, "samples/event.json-body.json"), "r"
    ) as f:
        return loads(f.read())


@pytest.fixture
def sample_b64_json_body():
    with open(
        os.path.join(config.project_root, "samples/event.b64-json-body.json"), "r"
    ) as f:
        return loads(f.read())


@pytest.fixture
def sample_url_body():
    with open(
        os.path.join(config.project_root, "samples/event.url-body.json"), "r"
    ) as f:
        return loads(f.read())


@pytest.fixture
def sample_b64_url_body():
    with open(
        os.path.join(config.project_root, "samples/event.b64-url-body.json"), "r"
    ) as f:
        return loads(f.read())


def test_json_body(sample_json_body):
    data = lambda_utils.data_from_event(sample_json_body)
    assert len(data) == 1
    assert data["name"] == "Sam"


def test_b64_json_body(sample_b64_json_body):
    data = lambda_utils.data_from_event(sample_b64_json_body)
    assert len(data) == 1
    assert data["name"] == "Sam"


def test_url_body(sample_url_body):
    data = lambda_utils.data_from_event(sample_url_body)
    assert len(data) == 1
    assert data["name"] == "Sam"


def test_b64_url_body(sample_b64_url_body):
    data = lambda_utils.data_from_event(sample_b64_url_body)
    print(data)
    assert len(data) == 1
    assert data["name"] == "Sam"


def test_check_basic_auth():
    def make_fake_event(auth_header):
        return {"headers": {"Authorization": auth_header}}

    with pytest.raises(lambda_utils.BasicAuthException, match="Missing Header"):
        lambda_utils.check_basic_auth({"headers": {}})

    with pytest.raises(
        lambda_utils.BasicAuthException, match="'Basic' Not in Authorization"
    ):
        lambda_utils.check_basic_auth(make_fake_event("fail"))

    with pytest.raises(lambda_utils.BasicAuthException, match="Decode Failure"):
        lambda_utils.check_basic_auth(make_fake_event("Basic Garbage"))

    with pytest.raises(lambda_utils.BasicAuthException, match="Too Many Chunks"):
        token = b64encode(b"will:not:work").decode("utf-8")
        lambda_utils.check_basic_auth(make_fake_event(f"Basic {token}"))

    with pytest.raises(lambda_utils.BasicAuthException, match="Invalid Username"):
        token = b64encode(b"bailey:warren").decode("utf-8")
        lambda_utils.check_basic_auth(make_fake_event(f"Basic {token}"))

    with pytest.raises(lambda_utils.BasicAuthException, match="Invalid Password"):
        token = b64encode(b"elizabeth:bailey").decode("utf-8")
        lambda_utils.check_basic_auth(make_fake_event(f"Basic {token}"))

    token = b64encode(b"elizabeth:warren").decode("utf-8")
    assert lambda_utils.check_basic_auth(make_fake_event(f"Basic {token}")) is True
