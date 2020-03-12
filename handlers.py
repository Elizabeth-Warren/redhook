#!/usr/bin/env python

import datetime

from redhook import transforms
from redhook.firehose import add_record
from redhook.lambda_utils import (
    from_body,
    handle_response,
    with_basic_auth,
)


@handle_response
@from_body
def json(data):
    return add_record(transforms.base(data))


@handle_response
@with_basic_auth
@from_body
def json_with_basic_auth(data):
    return add_record(transforms.base(data))


if __name__ == "__main__":
    print("Check imports...")
