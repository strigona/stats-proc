#!/usr/bin/sqsh -i
#
# $Id: dy_appendday.sql,v 1.2 2000/02/10 15:13:54 bwilson Exp $
#
# Appends the data from the daytables into the main tables
#
# Arguments:
#       Project

print "!! Appending day's activity to master tables"
go

print "::  Appending into csc_master"
go
insert into ${1}_master (date, id, team, blocks)
select
  d.timestamp as date,
  p.id,
  p.team,
  sum(d.size) as blocks
from ${1}_daytable_master d, STATS_participant p
where p.email = d.email
group by timestamp, id, team
go

print ":: Appending into csc_platform"
go
insert into ${1}_platform (date, cpu, os, ver, blocks)
select
  timestamp as date,
  cpu,
  os,
  ver,
  sum(size) as blocks
from ${1}_daytable_platform
group by timestamp, cpu, os, ver
go

