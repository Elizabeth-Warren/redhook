# redhook/test_firehose.py

from redhook.firehose import Firehose


class FakeClient:
    def __init__(self):
        self.first = True
        self.call_count = 0

    def put_record(self, **kwargs):
        self.call_count += 1
        if self.first:
            self.first = False
            raise Exception()
        return True


def test_firehose_retries():
    fake_client = FakeClient()
    firehose = Firehose(client=fake_client)
    assert firehose.add_record({"Hello": "World"})
    assert fake_client.call_count == 2
