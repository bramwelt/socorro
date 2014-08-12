# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import os
import socorro_lib.unittest.testlib.dbtestutil as dbtu

import socorro.lib.psycopghelper as psycopghelper
import socorro.lib.ConfigurationManager as configurationManager
import socorro_lib.database.postgresql as db_postgresql
import socorro_lib.database.schema as db_schema
import socorro_lib.database.database as sdatabase

from socorro.lib.datetimeutil import UTC, utc_now

from nose.tools import *
from socorro_lib.unittest.testlib.testDB import TestDB
import libTestconfig as testConfig
import socorro_lib.unittest.testlib.createJsonDumpStore as createJDS

import psycopg2

import datetime as dt
import errno
import logging
import os
import re
import time

logger = logging.getLogger()

class Me:  pass
me = None

def setup_module():
  global me
  if me:
    return
  me = Me()
  me.config = configurationManager.newConfiguration(configurationModule = testConfig, applicationName='Testing dbtestutil')
  myDir = os.path.split(__file__)[0]
  if not myDir: myDir = '.'
  replDict = {'testDir':'%s'%myDir}
  for i in me.config:
    try:
      me.config[i] = me.config.get(i)%(replDict)
    except:
      pass

  logger.setLevel(logging.DEBUG)
  logFilePathname = me.config.logFilePathname
  logfileDir = os.path.split(me.config.logFilePathname)[0]
  try:
    os.makedirs(logfileDir)
  except OSError,x:
    if errno.EEXIST != x.errno: raise
  f = open(me.config.logFilePathname,'w')
  f.close()

  fileLog = logging.FileHandler(logFilePathname, 'a')
  fileLog.setLevel(logging.DEBUG)
  fileLogFormatter = logging.Formatter(me.config.logFileLineFormatString)
  fileLog.setFormatter(fileLogFormatter)
  logger.addHandler(fileLog)
  me.database = sdatabase.Database(me.config)
  me.connection = me.database.connection()
  #me.dsn = "host=%(databaseHost)s dbname=%(databaseName)s user=%(databaseUserName)s password=%(databasePassword)s" % (me.config)
  #me.connection = psycopg2.connect(me.dsn)
  me.testDB = TestDB()
  # Remove/Create is being tested elsewhere via models.py & setupdb_app.py now
  me.testDB.removeDB(me.config,logger)
  me.testDB.createDB(me.config,logger)

def teardown_module():
  # Remove/Create is being tested elsewhere via models.py & setupdb_app.py now
  me.testDB.removeDB(me.config,logger)
  me.connection.close()
  if os.path.isfile(me.config.logFilePathname):
    os.remove(me.config.logFilePathname)

# this was a bad test in that it relies on the datetime in the database to be
# in sync with the datetime on the test machine
#def testDatetimeNow():
  #global me
  #cursor = me.connection.cursor()
  #before = dt.datetime.now()
  #time.sleep(.01)
  #got = dbtu.datetimeNow(cursor)
  #time.sleep(.01)
  #after = dt.datetime.now()
  #assert before < got and got < after, "but\nbefore:%s\ngot:   %s\nafter: %s"%(before,got,after)

def testFillProcessorTable_NoMap():
  """ testDbtestutil:testFillProcessorTable_NoMap():
  - check correct behavior for presence or absence of parameter 'stamp'
  - check correct number of entries created
  - check correct number of priority_job_X tables created
  """
  global me
  cursor = me.connection.cursor()
  ssql = "SELECT id,name,startdatetime,lastseendatetime FROM processors"
  dsql = "DELETE FROM processors"
  dropSql = "DROP TABLE IF EXISTS %s"
  stamps = [None,None,dt.datetime(2008,1,2,3,4,5,666,tzinfo=UTC),dt.datetime(2009,1,2,3,tzinfo=UTC), None, dt.datetime(2010,12,11,10,9,8,777,tzinfo=UTC)]
  try:
    for i in range(len(stamps)):
      before = utc_now()
      time.sleep(.01)
      dbtu.fillProcessorTable(cursor,i,stamp=stamps[i])
      time.sleep(.01)
      after =  utc_now()
      cursor.execute(ssql)
      data = cursor.fetchall()
      assert i == len(data)
      for d in data:
        if stamps[i]:
          assert stamps[i] == d[2]
          assert stamps[i] == d[3]
        else:
          assert before < d[2] and d[2] < after
          assert d[2] == d[3]
      priJobsTables = db_postgresql.tablesMatchingPattern("priority_jobs_%",cursor)
      assert i == len(priJobsTables)
      cursor.execute(dsql)
      if priJobsTables:
        cursor.execute(dropSql%(','.join(priJobsTables)))
      me.connection.commit()
  finally:
    pt = db_schema.ProcessorsTable(logger)
    pt.drop(cursor)
    pt.create(cursor)
    cursor.execute('DELETE FROM jobs')
    me.connection.commit()

def testFillProcessorTable_WithMap():
  """testDbtestutil:testFillProcessorTable_WithMap():
  - check that othr params ignored for non-empty map
  - check that mapped data is used correctly (id is ignored, mapped stamp is lastseendatetime)
  """
  global me
  cursor = me.connection.cursor()
  ssql = "SELECT id,name,startdatetime,lastseendatetime FROM processors"
  dsql = "DELETE FROM processors"
  dropSql = "DROP TABLE IF EXISTS %s"
  tmap = {12:dt.datetime(2008,3,4,5,6,12,tzinfo=UTC),37:dt.datetime(2009,5,6,7,8,37,tzinfo=UTC)}
  try:
    dbtu.fillProcessorTable(cursor,7,stamp=dt.datetime(2009,4,5,6,7,tzinfo=UTC),processorMap=tmap)
    cursor.execute(ssql)
    data = cursor.fetchall()
    me.connection.commit()
    assert 2 == len(data)
    expectSet = set([dt.datetime(2008,3,4,5,6,12,tzinfo=UTC),dt.datetime(2009,5,6,7,8,37,tzinfo=UTC)])
    gotSet = set()
    for d in data:
      assert dt.datetime(2009,4,5,6,7,tzinfo=UTC) == d[2]
      gotSet.add(d[3])
      assert d[0] in [1,2]
    assert expectSet == gotSet
  finally:
    pt = db_schema.ProcessorsTable(logger)
    pt.drop(cursor)
    pt.create(cursor)
    cursor.execute('DELETE FROM jobs')
    me.connection.commit()

def testMoreUuid():
  m = {'hexD':'[0-9a-fA-F]'}
  p = '^%(hexD)s{8}-%(hexD)s{4}-%(hexD)s{4}-%(hexD)s{4}-%(hexD)s{12}$'%m
  rep = re.compile(p)
  gen = dbtu.moreUuid()
  seen = set()
  # surely no test set has more than 150K uuids... and we want to run in < 1 second
  for i in range(150000):
    d = gen.next()
    assert 36 == len(d)
    assert d not in seen
    assert rep.match(d)
    seen.add(d)

def _makeJobDetails(aMap):
  "This is a test, but it is also a setup for the next test, so it will run there, not alone"
  jdCount = {1:0,2:0,3:0,4:0}
  data = dbtu.makeJobDetails(aMap)
  for d in data:
    jdCount[d[2]] += 1
    assert '/' in d[0]
    assert d[1] in d[0]
  assert jdCount == aMap
  return data

def testAddSomeJobs():
  global me
  cursor = me.connection.cursor()
  cursor.execute("SELECT id from processors")
  me.connection.commit()
  jdMap = {1:1,2:2,3:3,4:0}
  xdMap = {1:set(),2:set(),3:set(),4:set()}
  gdMap = {1:set(),2:set(),3:set(),4:set()}
  data = _makeJobDetails(jdMap)
  for d in data:
    xdMap[d[2]].add(d)
  try:
    dbtu.fillProcessorTable(cursor,3,logger=logger)
    cursor.execute("SELECT id from processors")
    me.connection.commit()
    addedJobs = dbtu.addSomeJobs(cursor,jdMap)
    me.connection.commit()
    assert data == addedJobs
    cursor.execute("SELECT pathname,uuid,owner FROM jobs ORDER BY OWNER ASC")
    me.connection.commit()
    data2 = cursor.fetchall()
    assert len(data) == len(data2)
    for d in data2:
      gdMap[d[2]].add(d)
    assert xdMap == gdMap
  finally:
    pt = db_schema.ProcessorsTable(logger)
    pt.drop(cursor)
    pt.create(cursor)
    cursor.execute("DELETE from jobs")
    me.connection.commit()

def testSetPriority_Jobs():
  global me
  cursor = me.connection.cursor()
  try:
    dbtu.fillProcessorTable(cursor,3,stamp=dt.datetime(2008,3,4,5,6,7,tzinfo=UTC))
    cursor.execute("SELECT id FROM processors")
    me.connection.commit()
    counts = dict((x[0],x[0]) for x in cursor.fetchall())
    dbtu.addSomeJobs(cursor,counts,logger)
    cursor.execute("SELECT id FROM jobs")
    me.connection.commit()
    jobIds = [x[0] for x in cursor.fetchall()]
    half = len(jobIds)/2
    expectPri = jobIds[:half]
    expectNon = jobIds[half:]
    dbtu.setPriority(cursor,expectPri)
    cursor.execute("SELECT id FROM jobs WHERE priority > 0 ORDER BY id")
    gotPri = [x[0] for x in cursor.fetchall()]
    cursor.execute("SELECT id FROM jobs WHERE priority = 0 ORDER BY id")
    gotNon = [x[0] for x in cursor.fetchall()]
    me.connection.commit()
    assert expectPri == gotPri
    assert expectNon == gotNon
  finally:
    jt = db_schema.JobsTable(logger)
    jt.drop(cursor)
    jt.create(cursor)
    pt = db_schema.ProcessorsTable(logger)
    pt.drop(cursor)
    pt.create(cursor)
    me.connection.commit()

def testSetPriority_PriorityJobs():
  global me
  cursor = me.connection.cursor()
  try:
    dbtu.fillProcessorTable(cursor,3,stamp=dt.datetime(2008,3,4,5,6,7,tzinfo=UTC))
    cursor.execute("SELECT id FROM processors")
    counts = dict((x[0],x[0]) for x in cursor.fetchall())
    dbtu.addSomeJobs(cursor,counts,logger)
    cursor.execute("SELECT id,uuid FROM jobs")
    me.connection.commit()
    data = cursor.fetchall()
    jobIds = [x[0] for x in data]
    jobUuids = [x[1] for x in data]
    half = len(jobIds)/2
    expect1Pri = jobIds[:half]
    expect2Pri = jobIds[half:]
    expect1Uuid = sorted(jobUuids[:half])
    expect2Uuid = sorted(jobUuids[half:])
    dbtu.setPriority(cursor,expect1Pri,'priority_jobs_1')
    dbtu.setPriority(cursor,expect2Pri,'priority_jobs_2')
    sql = "SELECT uuid from %s ORDER BY uuid"
    cursor.execute(sql%'priority_jobs_1')
    got1Uuid = [x[0] for x in cursor.fetchall()]
    cursor.execute(sql%'priority_jobs_2')
    got2Uuid = [x[0] for x in cursor.fetchall()]
    me.connection.commit()
    assert expect1Uuid == got1Uuid
    assert expect2Uuid == got2Uuid
  finally:
    jt = db_schema.JobsTable(logger)
    jt.drop(cursor)
    jt.create(cursor)
    pt = db_schema.ProcessorsTable(logger)
    pt.drop(cursor)
    pt.create(cursor)
    me.connection.commit()

def testMoreUrl():
  global me
  noneGen = dbtu.moreUrl(False)
  for i in range(100):
    assert None == noneGen.next()

  allGen = dbtu.moreUrl(True,0)
  setAll = set()
  for i in range(40000):
    setAll.add(allGen.next())
  assert 2001 > len(setAll)
  assert 1998 < len(setAll)

  someGen5 = dbtu.moreUrl(True,5)
  set5 = set()
  for i in range(100):
    set5.add(someGen5.next())
  assert 5 >= len(set5)

  someGen100 = dbtu.moreUrl(True,100)
  set100 = set()
  for i in range(500):
    set100.add(someGen100.next())
  assert 100 >= len(set100)

  tooGen = dbtu.moreUrl(True,40000)
  setToo = set()
  for i in range(40000):
    setToo.add(tooGen.next())
  assert setToo == setAll
