#!/usr/bin/sqsh -i
#
# $Id: dp_em_rank.sql,v 1.1 2003/09/11 02:04:01 decibel Exp $
#
# Does the participant ranking (overall)
#
# Arguments:
#       Project

print "!! Begin CACHE_em_RANK Build"
go

use stats
set rowcount 0
go

revoke select on CACHE_em_RANK to public
go

while exists (select * from sysobjects where id = object_id(\\'CACHE_em_RANK_old\\'))
	drop table CACHE_em_RANK_old
go

while exists (select * from sysobjects where id = object_id(\\'CACHE_em_RANK\\'))
	EXEC sp_rename \\'CACHE_em_RANK', 'CACHE_em_RANK_old'
go

print "::  Creating CACHE_em_RANK table"
go
create table CACHE_em_RANK
(       idx numeric (10,0) IDENTITY NOT NULL,
        id numeric (10,0) NULL ,
	email varchar (64) NULL ,
	first smalldatetime NULL ,
	last smalldatetime NULL ,
	blocks numeric (10,0) NULL ,
	days_working int NULL ,
	overall_rate numeric (14,4) NULL ,
	rank int NULL,
	change int NULL,
        listmode int NULL
)
go

print "::  Filling cache table a with data (id,first,last,blocks)"
go
select id, min(date) as first, max(date) as last, sum(blocks) as blocks
	into #RANKa
	from RC5_64_master
	group by id
go

print "::  Honoring all retire_to requests"
go
update #RANKa
	set id = retire_to
	from STATS_Participant
	where STATS_Participant.id = #RANKa.id
		and retire_to <> STATS_Participant.id
		and retire_to > 0
go

print "::  Populating CACHE_em_RANK table"
go
insert into CACHE_em_RANK
	(id, email, first, last, blocks, days_working, rank, change, listmode, overall_rate)
	select p.id, max(p.email), min(r.first), max(r.last), sum(r.blocks),
		datediff(dd,min(r.first),max(r.last))+1 as days_working, 0 as rank, 0 as change, max(p.listmode),
		convert(numeric(14,4),sum(r.blocks)*268435.456/DateDiff(second,min(r.first),DateAdd(day,1,max(r.last)))) as overall_rate
	from #RANKa r, STATS_Participant p
	where r.id = p.id
		and listmode < 10
	group by p.id
	order by sum(r.blocks) desc, p.id
go

print "::  Calculating rank for participants"
go
select blocks, min(idx) as rank
	into #RANKb
	from CACHE_em_RANK
	group by blocks
go
create unique clustered index blocks on #RANKb(blocks)
go
update CACHE_em_RANK
	set rank = r.rank
	from #RANKb r
	where CACHE_em_RANK.blocks = r.blocks
go

print "::  Calculating offset from previous ranking"
go
update CACHE_em_RANK
	set change = old.rank - CACHE_em_RANK.rank
	from CACHE_em_RANK_old old
	where old.id = CACHE_em_RANK.id
go

print "::  Creating indexes"
go
create clustered index rank on CACHE_em_RANK(rank)
create unique index email on CACHE_em_RANK(email)
create unique index id on CACHE_em_RANK(id)
go
print ":: Updating statistics"
go
update statistics CACHE_em_RANK
go

grant select on CACHE_em_RANK to public
go

