#! /usr/bin/env python
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""This app tests that inserting a crash report into elasticsearch works.
It simply uses socorro.external.elasticsearch.crashstorage to send a report
and verifies that it was correctly inserted. """

# This app can be invoked like this:
#     .../socorro/integrationtest/test_elasticsearch_indexing_app.py --help
# set your path to make that simpler
# set both socorro and configman in your PYTHONPATH

import json

from configman import Namespace

from socorro.app import generic_app
from socorro.external.elasticsearch.crashstorage import (
    ElasticSearchCrashStorage
)
from socorro.lib.datetimeutil import string_to_datetime


class IntegrationTestElasticsearchStorageApp(generic_app.App):
    app_name = 'test_elasticsearch_indexing'
    app_version = '0.1'
    app_description = __doc__

    required_config = Namespace()
    required_config.add_option(
        'elasticsearch_storage_class',
        default=ElasticSearchCrashStorage,
        doc='The class to use to store crash reports in elasticsearch.'
    )

    required_config.add_option(
        'processed_crash_file',
        default='./testcrash/processed_crash.json',
        doc='The file containing the processed crash.'
    )

    required_config.add_option(
        'raw_crash_file',
        default='./testcrash/raw_crash.json',
        doc='The file containing the raw crash.'
    )

    def main(self):
        storage = self.config.elasticsearch_storage_class(self.config)

        crash_file = open(self.config.processed_crash_file)
        processed_crash = json.load(crash_file)

        crash_file = open(self.config.raw_crash_file)
        raw_crash = json.load(crash_file)

        crash_date = string_to_datetime(processed_crash['date_processed'])
        es_index = storage.get_index_for_crash(crash_date)
        es_doctype = self.config.elasticsearch_doctype
        crash_id = processed_crash['uuid']

        storage.save_raw_and_processed(
            raw_crash,
            None,
            processed_crash,
            crash_id
        )

        try:
            # Verify the crash has been inserted
            crash = storage.es.get(
                es_index,
                es_doctype,
                crash_id
            )
            assert crash['exists']

        finally:
            # Clean up created index.
            storage.es.delete_index(es_index)


if __name__ == '__main__':
    generic_app.main(IntegrationTestElasticsearchStorageApp)
    print 'done'
