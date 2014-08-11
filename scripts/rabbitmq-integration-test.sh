#!/bin/bash

# integration test for Socorro, using rabbitmq
#
# bring up components, submit test crash, ensure that it shows up in
# reports tables.
#
# This uses the same setup as http://socorro.readthedocs.org/en/latest/installation.html

if [ "$#" != "1" ] || [ "$1" != "--destroy" ]
then
  echo "WARNING - this script will destroy the local socorro install."
  echo "The default database and config files will be overwritten."
  echo "You must pass the --destroy flag to continue."
  exit 1
fi


if [ -z "$database_hostname" ]
then
  database_hostname="localhost"
fi

if [ -z "$database_username" ]
then
  database_username="breakpad_rw"
fi

if [ -z "$database_password" ]
then
  database_password="aPassword"
fi

if [ -z "$rmq_host" ]
then
  rmq_host="localhost"
fi

if [ -z "$rmq_user" ]
then
  rmq_user="guest"
fi

if [ -z "$rmq_password" ]
then
  rmq_password="guest"
fi

if [ -z "$rmq_virtual_host" ]
then
  rmq_virtual_host="/"
fi

function cleanup_rabbitmq() {
  echo -n "INFO: Purging rabbitmq queue 'socorro.normal'..."
  python scripts/test_rabbitmq.py --test_rabbitmq.purge='socorro.normal' --test_rabbitmq.rabbitmq_host=$rmq_host --test_rabbitmq.rabbitmq_user=$rmq_user --test_rabbitmq.rabbitmq_password=$rmq_password --test_rabbitmq.rabbitmq_vhost=$rmq_virtual_host > /dev/null 2>&1
  echo " Done."
  echo -n "INFO: Purging rabbitmq queue 'socorro.priority'..."
  python scripts/test_rabbitmq.py --test_rabbitmq.purge='socorro.priority' --test_rabbitmq.rabbitmq_host=$rmq_host --test_rabbitmq.rabbitmq_user=$rmq_user --test_rabbitmq.rabbitmq_password=$rmq_password --test_rabbitmq.rabbitmq_vhost=$rmq_virtual_host > /dev/null 2>&1
  echo " Done."
}

function cleanup() {
  cleanup_rabbitmq

  echo "INFO: cleaning up crash storage directories"
  rm -rf ./primaryCrashStore/ ./processedCrashStore/
  rm -rf ./crashes/

  echo "INFO: Terminating background jobs"

  for p in collector processor middleware
  do
    # destroy any running processes started by this shell
    kill `jobs -p`
    # destroy anything trying to write to the log files too
    fuser -k ${p}.log > /dev/null 2>&1
  done

  return 0
}

trap 'cleanup' INT

function fatal() {
  exit_code=$1
  message=$2

  echo "ERROR: $message"

  cleanup

  exit $exit_code
}

echo -n "INFO: setting up environment..."
source ${VIRTUAL_ENV:-"socorro-virtualenv"}/bin/activate >> setup.log 2>&1
if [ $? != 0 ]
then
  fatal 1 "could activate virtualenv"
fi
export PYTHONPATH=.
echo " Done."

echo -n "INFO: setting up database..."
python socorro/external/postgresql/setupdb_app.py --database_username=$database_username --database_password=$database_password --database_name=breakpad --database_hostname=$database_hostname --dropdb --force --fakedata --fakedata_days=1 > setupdb.log 2>&1
if [ $? != 0 ]
then
  fatal 1 "setupdb_app.py failed, check setupdb.log"
fi
echo " Done."
popd >> setupdb.log 2>&1

# ensure rabbitmq is really empty and no previous failure left garbage
cleanup_rabbitmq

echo -n "INFO: setting up 'weekly-reports-partitions' via crontabber..."
python socorro/cron/crontabber_app.py --resource.postgresql.database_hostname=$database_hostname --secrets.postgresql.database_username=$database_username --secrets.postgresql.database_password=$database_password --job=weekly-reports-partitions --force >> setupdb.log 2>&1
if [ $? != 0 ]
then
  fatal 1 "crontabber weekly-reports-partitions failed, check setupdb.log"
fi
echo " Done."

echo -n "INFO: configuring backend jobs..."
cp socorro-processor/config/processor.ini-dist config/processor.ini
for p in collector middleware
do
  cp config/${p}.ini-dist config/${p}.ini
  if [ $? != 0 ]
  then
    fatal 1 "copying default config for $p failed"
  fi
  # ensure no running processes
  fuser -k ${p}.log > /dev/null 2>&1
done
echo " Done."

echo -n "INFO: starting up collector, processor and middleware..."
python socorro/collector/collector_app.py --admin.conf=./config/collector.ini --storage.storage1.host=$rmq_host --storage.storage1.rabbitmq_user=$rmq_user --storage.storage1.rabbitmq_password=$rmq_password --storage.storage1.virtual_host=$rmq_virtual_host --storage.storage1.transaction_executor_class=socorro.database.transaction_executor.TransactionExecutor --web_server.wsgi_server_class=socorro.webapi.servers.CherryPy > collector.log 2>&1 &
socorro-processor --admin.conf=./config/processor.ini --processor.database_hostname=$database_hostname --new_crash_source.host=$rmq_host --new_crash_source.rabbitmq_user=$rmq_user --new_crash_source.rabbitmq_password=$rmq_password --new_crash_source.virtual_host=$rmq_virtual_host --destination.storage1.database_hostname=$database_hostname --registrar.database_hostname=$database_hostname > processor.log 2>&1 &
sleep 1
python socorro/middleware/middleware_app.py --admin.conf=./config/middleware.ini --database.database_hostname=$database_hostname --database.database_username=$database_username --database.database_password=$database_password --rabbitmq.host=$rmq_host --rabbitmq.rabbitmq_user=$rmq_user --rabbitmq.rabbitmq_password=$rmq_password --rabbitmq.virtual_host=$rmq_virtual_host --web_server.wsgi_server_class=socorro.webapi.servers.CherryPy > middleware.log 2>&1 &
echo " Done."

function retry() {
  name=$1
  search=$2

  count=0
  while true
  do
    grep "$search" ${name}.log > /dev/null
    if [ $? != 0 ]
    then
      echo "INFO: waiting for $name..."
      if [ $count == 30 ]
      then
        cat $name.log
        fatal 1 "$name timeout"
      fi
    else
      grep 'ERROR' ${name}.log
      if [ $? != 1 ]
      then
        fatal 1 "errors found in $name.log"
      fi
      echo "INFO: $name test passed"
      break
    fi
    sleep 5
    count=$((count+1))
  done
  }

# wait for collector to startup
retry 'collector' 'running standalone at 0.0.0.0:8882'

echo -n 'INFO: submitting test crash...'
# submit test crash
python socorro/collector/submitter_app.py -u http://localhost:8882/submit -s testcrash/raw/ -n 1 > submitter.log 2>&1
if [ $? != 0 ]
then
  fatal 1 "submitter failed, check submitter.log"
fi
echo " Done."

CRASHID=`grep 'CrashID' submitter.log | awk -FCrashID=bp- '{print $2}'`
if [ -z "$CRASHID" ]
then
  cat submitter.log
  fatal 1 "no crash ID found in submitter log"
fi

echo "INFO: collector received crash ID: $CRASHID"

# make sure crashes are picked up, and no errors are logged
retry 'collector' "$CRASHID"
retry 'processor' "$CRASHID"

# check that mware has raw crash
curl -s -D middleware_headers.log "http://localhost:8883/crash_data/?datatype=raw&uuid=${CRASHID}" > /dev/null
if [ $? != 0 ]
then
  echo "***** middleware log *****"
  cat middleware.log
  echo "***** END middleware log *****"
  fatal 1 "curl call to middleware for raw crash failed"
fi
grep '200 OK' middleware_headers.log > /dev/null
if [ $? != 0 ]
then
  fatal 1 "middleware test failed, no raw data for crash ID $CRASHID"
fi

# check that mware has processed crash in postgres
count=0
while true
do
  curl -s "http://localhost:8883/crash/?uuid=${CRASHID}"  | grep '"total": 1' > /dev/null
  if [ $? != 0 ]
  then
    echo "INFO: waiting for middleware..."
    if [ $count == 30 ]
    then
      fatal 1 "middleware test failed, crash ID $CRASHID not found"
    fi
  else
    break
  fi
  sleep 5
  count=$((count+1))
done

# check that mware logs the request for the crash, and logs no errors
retry 'middleware' "/crash_data"

cleanup
