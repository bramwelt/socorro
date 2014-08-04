from setuptools import setup

setup(
    name='socorro-processor',
    description='Processor of Crash Reports',
    version='95.0.0',
    author='Mozilla',
    author_email='socorro-dev@mozilla.com',
    url='https://crash-stats.mozilla.com',
    packages=['processor'],
    entry_points={
        'console_scripts': [
            'socorro-processor=processor.processor_app:main',
        ],
    },
    install_requires=['configman'],
)
