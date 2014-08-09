from setuptools import setup

setup(
    name="socorro.processor",
    description="processor...",
    author="Mozilla",
    author_email="socorro-dev@mozilla.com",
    license="MPL",
    version="0.1.0",
    url="http://github.com/mozilla/socorro",
    namespace_packages=['socorro'],
    packages=['socorro', 'socorro.processor'],
    entry_points={
        'console_scripts': ['socorro-processor=socorro.processor.processor_app:app']
        }
)
