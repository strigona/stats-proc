/* TM_RANK */

print "!! Begin CACHE_tm_RANK Build"
go

use stats
set flushmessage on
set rowcount 0
go

print "::  Creating PREBUILD_tm_RANK table"
go
while exists (select * from sysobjects where id = object_id('PREBUILD_tm_RANK'))
	drop table PREBUILD_tm_RANK
go
create table PREBUILD_tm_RANK 
(       Idx numeric (10,0) IDENTITY NOT NULL,
        Team numeric (10,0) NULL ,
	Name varchar (64) NULL ,
	First smalldatetime NULL ,
	Last smalldatetime NULL ,
	Blocks numeric (10,0) NULL ,
	Days_Working int NULL ,
	Overall_Rate numeric (14,4) NULL ,
	Rank int NULL,
	Change int NULL,
        ListMode int NULL,
	CurrentMembers int NULL,
        ActiveMembers int NULL,
	TotalMembers int NULL
)
go

print "::  Filling cache table a with data (team,first,last,blocks)"
go
select
 team,
 min(first) as First,
 max(last) as Last,
 Sum(blocks) as Blocks
into #TRANKa
from CACHE_tm_MEMBERS
group by team
go

print "::  Linking to team data into cache table b (name,days_working,listmode)"
go
declare @gdv smalldatetime
declare @gdva smalldatetime
select @gdv = getdate()
select @gdva = DateAdd(hh,8,@gdv)

-- Used to be datediff(dd,C.first,@gdv), which resulted in time working being off by one
select C.team, S.name, C.first, C.last, C.blocks,
  datediff(dd,C.first,C.last)+1 as Days_working,
  0 as rank, 0 as change,
  S.listmode 
into #TRANKb
from #TRANKa C, STATS_team S
where C.team = S.team
go 

print "::  Populating PREBUILD_tm_RANK live table"
go
insert into PREBUILD_tm_RANK 
  (team,name,first,last,blocks,days_working,rank,change,listmode)
select team, max(name),min(first),max(last),sum(blocks),max(days_working),min(rank),min(change),max(listmode)
from #TRANKb
where listmode < 10
group by team
order by blocks desc, team desc
go

print "::  Setting # of Current members"
go

declare @today smalldatetime
select @today = max(date) from rc5_64_master
select tj.team_id, count(*) as members 
	into #curmema
	from Team_Joins tj, STATS_Participant sp
	where sp.id = tj.id
		and sp.retire_to = 0
		and sp.listmode < 10
		and (tj.last_date >= @today or tj.last_date is NULL)
	group by team_id
go

create unique clustered index team on #curmema(team_id) with fillfactor = 100
go

update PREBUILD_tm_RANK
set CurrentMembers = T.members
from PREBUILD_tm_RANK C, #curmema T
where T.team_id = C.team
go
drop table #curmema

print "::  Setting # of total members"
go

select team, count(*) as members
into #curmemb
from CACHE_tm_MEMBERS
group by team
go

create unique clustered index team on #curmemb(team) with fillfactor = 100
go

update PREBUILD_tm_RANK
set TotalMembers = T.members
from PREBUILD_tm_RANK C, #curmemb T
where T.team = C.team
go
drop table #curmemb

print "::  Setting # of Active members"
go

declare @mdv smalldatetime
select @mdv = max(date)
from RC5_64_master

select team, count(*) as members
into #curmemc
from CACHE_tm_MEMBERS
where last >= dateadd(day, -7, @mdv)
group by team
go

create unique clustered index team on #curmemc(team) with fillfactor = 100
go

update PREBUILD_tm_RANK
set ActiveMembers = T.members
from PREBUILD_tm_RANK C, #curmemc T
where T.team = C.team
go
drop table #curmemc


print "::  Updating rank values to idx values (ranking step 1)"
go
update PREBUILD_tm_RANK
  set rank = idx,
      overall_rate = convert(numeric(14,4),Blocks*268435.456/DateDiff(ss,First,DateAdd(dd,1,Last)))
go

print "::  Indexing on blocks for ranking acceleration"
go
create index tempindex on PREBUILD_tm_RANK(blocks) with fillfactor = 100
go

print "::  Correcting rank for tied teams"
go
update PREBUILD_tm_RANK
set rank = (select min(btb.rank) from PREBUILD_tm_RANK btb where btb.blocks = PREBUILD_tm_RANK.blocks)
where (select count(btb.blocks) from PREBUILD_tm_RANK btb where btb.blocks = PREBUILD_tm_RANK.blocks) > 1
go

drop index PREBUILD_tm_RANK.tempindex

print "::  Creating team indexes"
go
create unique index team on PREBUILD_tm_RANK(team) with fillfactor = 100
go

print "::  Calculating offset from previous ranking"
go
update PREBUILD_tm_RANK
 set change = old.rank - PREBUILD_tm_RANK.rank
 from CACHE_tm_RANK old
 where old.team = PREBUILD_tm_RANK.team
go

print ":: Creating rank index"
create clustered index rank on PREBUILD_tm_RANK(rank) with fillfactor = 100
go

grant select on PREBUILD_tm_RANK  to public
go
while exists (select * from sysobjects where id = object_id('CACHE_tm_RANK'))
	drop table CACHE_tm_RANK
go
sp_rename PREBUILD_tm_RANK, CACHE_tm_RANK
go

while exists (select * from sysobjects where id = object_id('rc5_64_CACHE_tm_RANK'))
	drop view rc5_64_CACHE_tm_RANK
go
create view rc5_64_CACHE_tm_RANK as select * from CACHE_tm_RANK
go
grant select on rc5_64_CACHE_tm_RANK to public
go

