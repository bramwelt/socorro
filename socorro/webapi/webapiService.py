# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import json
import logging
import web

import socorro_lib.util as util
import socorro.database.database as db
import socorro.storage.crashstorage as cs
from socorro.external import (
    DatabaseError,
    InsertionError,
    MissingArgumentError,
    BadArgumentError
)


logger = logging.getLogger("webapi")


def typeConversion(type_converters, values_to_convert):
    """
    Convert a list of values into new types and return the new list.
    """
    return (t(v) for t, v in zip(type_converters, values_to_convert))


class BadRequest(web.webapi.HTTPError):
    """The only reason to override this exception class here instead of using
    the one in web.webapi is so that we can pass a custom message into the
    exception so the client can get a hint of what went wrong.
    """
    def __init__(self, message="bad request"):
        status = "400 Bad Request"
        if message and isinstance(message, dict):
            headers = {'Content-Type': 'application/json; charset=UTF-8'}
            message = json.dumps(message)
        else:
            headers = {'Content-Type': 'text/html'}
        super(BadRequest, self).__init__(status, headers, message)


class Timeout(web.webapi.HTTPError):
    """
    '408 Request Timeout' Error

    """
    def __init__(self, message="item currently unavailable"):
        status = "408 Request Timeout"
        if message and isinstance(message, dict):
            headers = {'Content-Type': 'application/json; charset=UTF-8'}
            message = json.dumps(message)
        else:
            headers = {'Content-Type': 'text/html'}
        super(Timeout, self).__init__(status, headers, message)


class NotFound(web.webapi.HTTPError):
    """Return a HTTPError with status code 404 and a description in JSON"""
    def __init__(self, message="Not found"):
        if isinstance(message, dict):
            message = json.dumps(message)
            headers = {'Content-Type': 'application/json; charset=UTF-8'}
        else:
            headers = {'Content-Type': 'text/html'}
        status = '404 Not Found'
        super(NotFound, self).__init__(status, headers, message)


class JsonWebServiceBase(object):

    """
    Provide an interface for JSON-based web services.

    """

    def __init__(self, config):
        """
        Set the DB and the pool up and store the config.
        """
        self.context = config

    def GET(self, *args):
        """
        Call the get method defined in a subclass and return its result.

        Return a JSON dump of the returned value,
        or the raw result if a content type was returned.

        """
        try:
            result = self.get(*args)
            if isinstance(result, tuple):
                web.header('Content-Type', result[1])
                return result[0]
            web.header('Content-Type', 'application/json')
            return json.dumps(result)
        except web.webapi.HTTPError:
            raise
        except (DatabaseError, InsertionError), e:
            raise web.webapi.InternalError(message=str(e))
        except (MissingArgumentError, BadArgumentError), e:
            raise BadRequest(str(e))
        except Exception:
            stringLogger = util.StringLogger()
            util.reportExceptionAndContinue(stringLogger)
            try:
                util.reportExceptionAndContinue(self.context.logger)
            except (AttributeError, KeyError):
                pass
            raise Exception(stringLogger.getMessages())

    def get(self, *args):
        raise NotImplementedError(
                    "The GET function has not been implemented for %s" % repr(args))

    def POST(self, *args):
        """
        Call the post method defined in a subclass and return its result.

        Return a JSON dump of the returned value,
        or the raw result if a content type was returned.

        """
        try:
            result = self.post(*args)
            if isinstance(result, tuple):
                web.header('Content-Type', result[1])
                return result[0]
            web.header('Content-Type', 'application/json')
            return json.dumps(result)
        except web.HTTPError:
            raise
        except (DatabaseError, InsertionError), e:
            raise web.webapi.InternalError(message=str(e))
        except (MissingArgumentError, BadArgumentError), e:
            raise BadRequest(str(e))
        except Exception:
            util.reportExceptionAndContinue(self.context.logger)
            raise

    def post(self, *args):
        raise NotImplementedError(
                    "The POST function has not been implemented.")

    def PUT(self, *args):
        """
        Call the put method defined in a subclass and return its result.

        Return a JSON dump of the returned value,
        or the raw result if a content type was returned.

        """
        try:
            result = self.put(*args)
            if isinstance(result, tuple):
                web.header('Content-Type', result[1])
                return result[0]
            web.header('Content-Type', 'application/json')
            return json.dumps(result)
        except web.HTTPError:
            raise
        except Exception:
            util.reportExceptionAndContinue(self.context.logger)
            raise

    def put(self, *args):
        raise NotImplementedError(
                    "The PUT function has not been implemented.")


class JsonServiceBase(JsonWebServiceBase):

    """Provide an interface for JSON-based web services. For legacy services,
    to be removed when all services are updated.
    """

    def __init__(self, config):
        """
        Set the DB and the pool up and store the config.
        """
        super(JsonServiceBase, self).__init__(config)
        try:
            self.database = db.Database(config)
            self.crashStoragePool = cs.CrashStoragePool(config,
                                        storageClass=config.hbaseStorageClass)
        except (AttributeError, KeyError):
            util.reportExceptionAndContinue(logger)
