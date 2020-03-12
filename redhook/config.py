# core/config.py

import os
import os.path

from cached_property import cached_property


class Config:
    @cached_property
    def project_root(self):
        """Where is the redhook directory?"""
        return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    @cached_property
    def delivery_stream(self):
        """Where are we sending the data?"""
        return os.environ["DELIVERY_STREAM_NAME"]

    @cached_property
    def basic_auth_username(self):
        return os.environ["BASIC_AUTH_USERNAME"]

    @cached_property
    def basic_auth_password(self):
        return os.environ["BASIC_AUTH_PASSWORD"]

config = Config()
