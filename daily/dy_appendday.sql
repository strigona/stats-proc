#!/usr/bin/sqsh -i
#
# $Id: dy_appendday.sql,v 1.8 2000/06/27 06:24:26 decibel Exp $
#
# Appends the data from the daytables into the main tables
#
# Arguments:
#       PROJECT_ID

print "!! Appending day's activity to master tables"
go

print "::  Appending into Email_Contrib"
go
declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

insert into Email_Contrib (DATE, PROJECT_ID, ID, TEAM_ID, WORK_UNITS)
	select @proj_date, ${1}, ID, TEAM_ID, d.WORK_UNITS
	from Email_Contrib_Today d
	where d.PROJECT_ID = ${1}
	/* Group by is unnecessary, data is already summarized */
go

print ":: Appending into Platform_Contrib"
go
declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

insert into Platform_Contrib (DATE, PROJECT_ID, CPU, OS, VER, WORK_UNITS)
	select @proj_date, ${1}, CPU, OS, VER, WORK_UNITS
	from Platform_Contrib_Today
	where PROJECT_ID = ${1}
	/* Group by is unnecessary, data is already summarized */
go

print ":: Assigning old work to current team"
go
update Email_Contrib
	set TEAM_ID = sp.TEAM
	from STATS_Participant sp
	where Email_Contrib.TEAM_ID = 0
		and Email_Contrib.PROJECT_ID = ${1}
		and sp.ID = Email_Contrib.ID
		and sp.TEAM >= 1
go
