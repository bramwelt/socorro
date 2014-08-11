# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import calendar
from collections import defaultdict

from socorro_lib.external import BadArgumentError
from socorro_lib.external.postgresql.base import PostgreSQLBase
from socorro_lib import external_common


class LagLog(PostgreSQLBase):

    def get(self, **kwargs):

        filters = [
            ('limit', 500, 'int'),
            ('offset', 0, 'int'),
        ]
        params = external_common.parse_arguments(filters, kwargs)
        if params['limit'] > 1000:
            raise BadArgumentError('Max limit is 1000')

        sql = """
            /* socorro_lib.external.postgresql.laglog.LagLog.get */
            SELECT
                replica_name,
                lag,
                moment,
                master,
                AVG(lag)
            OVER (
                PARTITION BY replica_name
                ORDER BY moment DESC
                ROWS BETWEEN 0 FOLLOWING AND 11 FOLLOWING
            ) AS average
            FROM lag_log
            ORDER BY moment DESC
            LIMIT %(limit)s
            OFFSET %(offset)s
        """

        results = self.query(sql, params)
        averages = defaultdict(list)
        all = defaultdict(list)
        for row in results:
            replica_name = row[0]
            lag = row[1]
            moment = row[2]
            master = row[3]
            average = row[4]
            timestamp = calendar.timegm(moment.utctimetuple())
            all[replica_name].append({
                'x': timestamp,
                'y': lag,
                'master': master
            })
            if not average:
                average = 0
            averages[replica_name].append({
                'x': timestamp,
                'y': int(average)
            })

        max_bytes_critical = self.context.laglog.max_bytes_critical
        max_bytes_warning = self.context.laglog.max_bytes_warning

        replicas = []
        for name, rows in all.items():
            message = None
            last_average = averages[name][0]['y']
            last_value = rows[0]['y']
            if last_average > max_bytes_critical:
                message = 'CRITICAL'
            elif last_average > max_bytes_warning:
                message = 'WARNING'

            rows.reverse()
            averages_rows = averages[name]
            averages_rows.reverse()
            replicas.append({
                'name': name,
                'rows': rows,
                'averages': averages_rows,
                'message': message,
                'last_average': last_average,
                'last_value': last_value,
            })
        replicas.sort(key=lambda x: x['name'])

        return {'replicas': replicas}
