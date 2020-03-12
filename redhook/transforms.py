# core/transforms.py

from copy import deepcopy as clone
from json import dumps


def merge(root, *others):
    """Combine a bunch of dictionaries and return the result"""
    cp = clone(root)
    [cp.update(other) for other in others]
    return cp


class transform:
    """compose a series of transformation functions"""

    @staticmethod
    def __recursively_flatten(current, key, result):
        if isinstance(current, dict):
            for k in current:
                flat_key = f"{key}_{k.lower()}" if key else k
                transform.__recursively_flatten(current[k], flat_key, result)
        else:
            result[key] = current
        return result

    @staticmethod
    def flatten_dict(value):
        return transform.__recursively_flatten(value, "", {})

    def __init__(self):
        self.__chain = []

    def flatten(self):
        """When invoked, the transform will flatten deeply nested dictionaries"""
        self.__chain.append(transform.flatten_dict)
        return self

    def __call__(self, value):
        """When invoked, this will pass the given value through the configured set of transformations"""
        result = clone(value)
        for fn in reversed(self.__chain):
            result = fn(result)
        result["__raw"] = dumps(value)
        return result


base = transform().flatten()
