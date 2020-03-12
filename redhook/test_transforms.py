# tests/transforms.py

import os.path
from json import dumps, loads


from . import transforms
from .config import config


def test_value():
    value = {"hello": "world"}
    result = transforms.transform()(value)

    assert len(result) == 2
    assert result["__raw"] == dumps(value)
    assert result["hello"] == "world"


def test_flatten():
    obj = {
        "hello": {"world": {"a": 1, "b": 2, "c": 3}},
        "goodbye": {"this": {"that": [0, 1]}, "foo": {"bar": "whoops"}},
    }

    results = transforms.base(obj)

    assert len(results) == 6
    assert "__raw" in results
    assert results["hello_world_a"] == 1
    assert results["hello_world_b"] == 2
    assert results["hello_world_c"] == 3
    assert results["goodbye_this_that"] == [0, 1]
    assert results["goodbye_foo_bar"] == "whoops"

