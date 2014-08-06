"""
Script for managing the building, installation, and testing of
socorro-crashstats
"""
from setuptools import setup, find_packages

def get_long_description():
    """
    Output a full description of socorro-crashstats
    """
    with open('README.md') as f:
        return f.read()

setup(
    name='crashstats',
    version='1.0',
    description='Socorro Django Admin UI',
    url='https://github.com/mozilla/socorro/tree/master/webapp-django',
    author='Mozilla',
    author_email='socorro-dev@mozilla.com',
    long_description=get_long_description(),
    license='MPL',
    include_package_data=True,
    classifiers=[],
    install_requires=[
        'BeautifulSoup',
        'cef',
        'commonware',
        'cssselect',
        'Django',
        'django-appconf',
        'django-browserid',
        'django-compressor',
        'django-nose',
        'django-session-csrf',
        'django-sha2',
        'django-ratelimit',
        'django-waffle',
        'funfactory',
        'isodate',
        'jingo',
        'Jinja2',
        'lxml',
        'mock',
        'nose',
        'nuggets',
        'ordereddict',
        'pep8',
        'pyflakes',
        'pyquery',
        'raven',
        'requests',
        'six',
        'test-utils',
    ],
    packages=find_packages(exclude=['tests']),
)
