#!/usr/bin/sqsh -i
#
# $Id: audit.sql,v 1.3 2000/06/27 06:23:47 decibel Exp $

create table #audit (
	ECTsum		numeric(20),
	ECsumtoday	numeric(20),
	PCTsum		numeric(20),
	PCsumtoday	numeric(20),
	DSunits		numeric(20),
	DSusers		int,
	ECsum		numeric(20),
	PCsum		numeric(20),
	DSsum 		numeric(20),
	ECTblcksum	numeric(20),
	ECblcksumtdy	numeric(20),
	ECblcksum	numeric(20),
	ERsumtoday	numeric(20),
	ERsum		numeric(20)
)
go -f -h
insert into #audit values(0,0,0,0,0,0,0,0,0,0,0,0,0,0)
go -f -h

print "Sum of work in Email_Contrib_Today for project id %1!", ${1}
go -f -h
update	#audit
	set ECTsum = (select sum(WORK_UNITS)
		from Email_Contrib_Today
		where PROJECT_ID = ${1})
select ECTsum from #audit
go -f -h

declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

print "Sum of work in Email_Contrib for today (%1!)", @proj_date
go -f -h
declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

update	#audit
	set ECsumtoday = (select sum(WORK_UNITS)
		from Email_Contrib
		where PROJECT_ID = ${1}
			and DATE = @proj_date)
select ECsumtoday from #audit
go -f -h

print "Sum of work in Platform_Contrib_Today for project id %1!", ${1}
go -f -h
update	#audit
	set PCTsum = (select sum(WORK_UNITS)
		from Platform_Contrib_Today
		where PROJECT_ID = ${1})
select PCTsum from #audit
go -f -h

declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

print "Sum of work in Platform_Contrib for today (%1!)", @proj_date
go -f -h
declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

update	#audit
	set PCsumtoday = (select sum(WORK_UNITS)
		from Platform_Contrib
		where PROJECT_ID = ${1}
			and DATE = @proj_date)
select PCsumtoday from #audit
go -f -h

declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

print "Work Units, Participants in Daily_Summary for today (%1!)", @proj_date
go -f -h
declare @proj_date smalldatetime
declare @units numeric(20)
declare @participants int
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

select	@units = WORK_UNITS, @participants = PARTICIPANTS
	from Daily_Summary
	where DATE = @proj_date
		and PROJECT_ID = ${1}
update	#audit
	set DSunits = @units, DSusers = @participants
select @units, @participants
go -f -h

print "Total work units in Email_Contrib"
go -f -h
update	#audit
	set ECsum = (select sum(WORK_UNITS)
		from Email_Contrib
		where PROJECT_ID = ${1})
select ECsum from #audit
go -f -h

print "Total work units in Platform_Contrib"
go -f -h
update 	#audit
	set PCsum = (select sum(WORK_UNITS)
		from Platform_Contrib
		where PROJECT_ID = ${1})
select PCsum from #audit
go -f -h

print "Total work units in Daily_Summary"
go -f -h
update	#audit
	set DSsum = (select sum(WORK_UNITS)
		from Daily_Summary
		where PROJECT_ID = ${1})
select DSsum from #audit
go -f -h

print "Total work units ignored today (listmode >= 10)"
go -f -h
update	#audit
	set ECTblcksum = (select sum(d.WORK_UNITS)
		from Email_Contrib_Today d, STATS_Participant p
		where PROJECT_ID = ${1}
			and d.ID = p.ID
			and p.LISTMODE >= 10)
select ECTblcksum from #audit
go -f -h

print "Total work units ignored in Email_Contrib for today (listmode >= 10)"
go -f -h
declare @proj_date smalldatetime
select @proj_date = LAST_STATS_DATE
	from Projects
	where PROJECT_ID = ${1}

update	#audit
	set ECblcksumtdy = (select sum(e.WORK_UNITS)
		from Email_Contrib e, STATS_Participant p
		where PROJECT_ID = ${1}
			and e.LAST_DATE = @proj_date
			and e.ID = p.ID
			and p.LISTMODE >= 10)
select ECblcksumtdy from #audit
go -f -h

print "Total work units ignored overall (listmode >= 10)"
go -f -h
update	#audit
	set ECblcksum = (select sum(e.WORK_UNITS)
		from Email_Contrib e, STATS_Participant p
		where PROJECT_ID = ${1}
			and e.ID = p.ID
			and p.LISTMODE >= 10)
select ECblcksum from #audit
go -f -h

print "Total work reported in Email_Rank for Today, Overall"
go -f -h
declare @ERsumtoday numeric(20)
declare @ERsum numeric(20)
select	@ERsumtoday = sum(WORK_TODAY), @ERsum = sum(WORK_TOTAL)
	from Email_Rank
	where PROJECT_ID = ${1}
update	#audit
	set ERsumtoday = @ERsumtoday, ERsum = @ERsum
select @ERsumtoday, @ERsum
go -f -h

print "!! begin sanity checks !!"
go

/* ECTsum, ECsumtoday, PCTsum, PCsumtoday, and DSunits should all match */
print "checking total work units submitted today...."
declare @ECTsum numeric(20)
declare @ECsumtoday numeric(20)
declare @PCTsum numeric(20)
declare @PCsumtoday numeric(20)
declare @DSunits numeric(20)
select	@ECTsum = ECTsum, @ECsumtoday = ECsumtoday,
	@PCTsum = PCTsum, @PCsumtoday = PCsumtoday,
	@DSunits = DSunits
	from #audit
if (@ECTsum <> @ECsumtoday)
	print "ERROR! Email_Contrib_Today sum (ECTsum=%1!) != Email_Contrib sum for today (ECsumtoday=%2!)", @ECTsum, @ECsumtoday
if (@ECTsum <> @PCTsum)
	print "ERROR! Email_Contrib_Today sum (ECTsum=%1!) != Platform_Contrib_Today sum (PCTsum=%2!)", @ECTsum, @PCTsum
if (@ECTsum <> @PCsumtoday)
	print "ERROR! Email_Contrib_Today sum (ECTsum=%1!) != Platform_Contrib sum for today (PCsumtoday=%2!)", @ECTsum, @PCsumtoday
if (@ECTsum <> @DSunits)
	print "ERROR! Email_Contrib_Today sum (ECTsum=%1!) != Daily_Summary for today (DSunits=%2!)", @ECTsum, @DSunits
go -f -h

/* ECsum, PCsum, and DSsum should all match */
print "checking total work units submitted...."
declare @ECsum numeric(20)
declare @PCsum numeric(20)
declare @DSsum numeric(20)
select	@ECsum = ECsum, @PCsum = PCsum, @DSsum = DSsum
	from #audit
if (@ECsum <> @PCsum)
	print "ERROR! Email_Contrib sum (ECsum=%1!) != Platform_Contrib sum (PCsum=%2!)", @ECsum, @PCsum
if (@ECsum <> @DSsum)
	print "ERROR! Email_Contrib sum (ECsum=%1!) != Daily_Summary sum (DSsum=%2!)", @ECsum, @DSsum
go -f -h

/* ECTblcksum should equal ECblcksumtdy */
print "checking total units blocked today..."
declare @ECTblcksum numeric(20)
declare @ECblcksumtdy numeric(20)
declare @ERsumtoday numeric(20)
declare @ECTsum numeric(20)
select @ECTblcksum = ECTblcksum, @ECblcksumtdy = ECblcksumtdy,
	@ERsumtoday = ERsumtoday, @ECTsum = ECTsum
	from #audit
if (@ECTblcksum <> @ECblcksumtdy)
	print "ERROR! EMail_Contrib_Today blocked sum (ECTblcksum=%1!) != Email_Contrib blocked sum for today (ECblcksumtdy=%2!)", @ECTblcksum, @ECblcksumtdy

/* ECTblcksum + ERsumtoday should equal ECTsum */
if ( (@ECTblcksum + @ERsumtoday) <> @ECTsum )
	print "ERROR! Email_Contrib_Today blocked sum (ECTblcksum=%1!) + Email_Rank sum today (ERsumtoday=%2!) != Email_Contrib_Today sum (ECTsum=%3!)", @ECTblcksum, @ERsumtoday, @ECTsum
go -f -h

/* ECblcksum + ERsum should equal ECsum */
declare @ECblcksum numeric(20)
declare @ERsum numeric(20)
declare @ECsum numeric(20)
select	@ECblcksum = ECblcksum, @ERsum = ERsum, @ECsum = ECsum
	from #audit
if ( (@ECblcksum + @ERsum) <> @ECsum)
	print "ERROR! Email_Contrib blocked sum (ECblcksum=%1!) + Email_Rank sum (ERsum=%2!) != Email_Contrib sum (ECsum=%3!)", @ECblcksum, @ERsum, @ECsum
go -f -h
