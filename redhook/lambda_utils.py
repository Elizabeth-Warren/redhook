# core/lambda_utils.py

import logging
from base64 import b64decode
from functools import wraps
from json import dumps, loads
from os import environ
from urllib import parse

from .config import config


class BasicAuthException(Exception):
    """Helper to emit when basic-auth check fail"""

    pass


class StripeSignatureException(Exception):
    """Helper to emit when stripe sig check fail"""

    pass


def error():
    """Returns the representation of an error"""
    return {
        "statusCode": 500,
        "body": dumps({"message": "FAIL"}),
        "headers": {"Content-Type": "application/json"},
    }


def ok():
    """Returns the representation of an OK message"""
    return {
        "statusCode": 200,
        "body": dumps({"message": "OK"}),
        "headers": {"Content-Type": "application/json"},
    }


def basic_auth_error():
    return {
        "statusCode": 401,
        "body": "Could not verify your access level for that URL. You have to login with proper credentials",
        "headers": {"WWW-Authenticate": 'Basic realm="Login Required"'},
    }


def handle_response(f):
    """Decorates the passed function such that it will respond with the
    apporpriate response to the API gateway and send messages to cloudwatch
    on uncaught exceptions
    """

    @wraps(f)
    def wrapped(*args, **kwargs):
        try:
            f(*args, **kwargs)
        except BasicAuthException:
            logging.error(f"{f.__name__} - basic auth check failed...")
            return basic_auth_error()
        except Exception:
            logging.exception(f"{f.__name__} - handler failed...")
            return error()
        else:
            return ok()

    return wrapped


decoders = {
    "json": loads,
    "application/x-www-form-urlencoded": lambda x: dict(parse.parse_qsl(x)),
}


def get_decoder(content_type):
    """Get the decoder from the above map, default to json loads"""
    return decoders.get(content_type, loads)


def data_from_event(event):
    # At this point, we assume that the event input is a valid api gateway
    # object. If it isn't, we're just going to blow up anyways
    body = event["body"]
    is_base64 = event.get("isBase64Encoded", False)
    content_type = event.get("headers", {}).get("Content-Type", "No Content Type")
    decode = get_decoder(content_type)

    if is_base64:
        body = b64decode(body).decode("utf-8")

    try:
        data = decode(body)
    except Exception:
        s = f"Failed decoding message. (Content-Type: {content_type}, isBase64?: {is_base64})"
        logging.exception(s)
        raise Exception(s)
    else:
        return data


def from_body(f):
    """Decorates a function to extract data from the body of a message posted
    to redhook
    """

    @wraps(f)
    def wrapped(event, context):
        return f(data_from_event(event))

    return wrapped


def check_basic_auth(event):
    auth = event.get("headers", {}).get("Authorization")
    if not auth:
        raise BasicAuthException("Missing Header")

    if not auth.startswith("Basic "):
        raise BasicAuthException("'Basic' Not in Authorization")

    try:
        token = auth.split(" ")[1]
        decoded = b64decode(token).decode("utf-8").split(":")
    except Exception:
        logging.exception("Failed decoding Basic Auth token")
        raise BasicAuthException("Decode Failure")

    if len(decoded) != 2:
        raise BasicAuthException("Too Many Chunks")

    if not decoded[0] == config.basic_auth_username:
        raise BasicAuthException("Invalid Username")

    if not decoded[1] == config.basic_auth_password:
        raise BasicAuthException("Invalid Password")

    return True


def with_basic_auth(f):
    """Use basic authentication on the endpoint"""

    @wraps(f)
    def wrapped(event, context):
        check_basic_auth(event)
        return f(event, context)

    return wrapped
