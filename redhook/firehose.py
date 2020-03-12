# redhook/firehose.py

import logging
from json import dumps
from os import environ
from random import random
from time import sleep

import boto3

from cached_property import cached_property

from .config import config


class Firehose:
    @staticmethod
    def randomized_sleep(base, fudge_factor=2):
        return base + (fudge_factor * random())

    def __init__(self, client=None):
        self.__client = client

    @cached_property
    def client(self):
        """The firehose client"""
        return self.__client or boto3.client("firehose")

    def add_record(self, data, retries=10, sleep_time=2):
        """Deliver a JSON-serializable dictionary to the firehose"""
        # We are not going to backoff at all here, it should be able to handle
        # it.
        try:
            return self.client.put_record(
                DeliveryStreamName=config.delivery_stream,
                Record={"Data": dumps(data) + "\n"},
            )
        except Exception as e:
            logging.error("Failed writing data to firehose.")
            if not retries:
                raise e

            actual_sleep_time = Firehose.randomized_sleep(sleep_time)
            sleep(actual_sleep_time)
            logging.warning(
                f"Slept for {actual_sleep_time}s. Retrying (retries remaining: {retries})"
            )
            return self.add_record(data, retries=retries - 1, sleep_time=sleep_time)


add_record = Firehose().add_record
