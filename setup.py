import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="redhook",
    version="0.0.1",
    author="Elizabeth Warren",
    author_email="pstein@elizabethwarren.com",
    description="Redhook Codebase",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://www.elizabethwarren.com",
    packages=setuptools.find_packages(),
    python_requires=">=3.7",
)
