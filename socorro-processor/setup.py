from setuptools import setup

setup(
    name="socorro-processor",
    description="processor...",
    author="Mozilla",
    author_email="socorro-dev@mozilla.com",
    license="MPL",
    version="0.1.0",
    url="http://github.com/mozilla/socorro",
    packages=['socorro_processor'],
    test_suite='nose.collector',
    install_requires=[
        'socorro-lib==0.1.0',
    ],
    entry_points={
        'console_scripts': ['socorro-processor=socorro_processor.processor_app:app']
    }
)
