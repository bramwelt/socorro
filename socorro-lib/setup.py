from setuptools import setup

setup(
    name="socorro-lib",
    description="Shared library for Socorro",
    author="Mozilla",
    author_email="socorro-dev@mozilla.com",
    license="MPL",
    version="0.1.0",
    url="http://github.com/mozilla/socorro",
    packages=['socorro_lib'],
    test_suite='nose.collector',
    install_requires=[
        'configman',
        'sqlalchemy',
        'psycopg2',
        'isodate',
    ],
)
