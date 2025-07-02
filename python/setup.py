# python/setup.py
from setuptools import find_packages, setup

setup(
    name='my-script-lib',
    version='0.1.0',
    packages=find_packages(),
    description='A common library for Python scripts.',
    author='Your Name',
    install_requires=[
        'colorlog',
    ],
)
