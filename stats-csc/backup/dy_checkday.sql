#!/usr/bin/sqsh -i
#
# $Id: dy_checkday.sql,v 1.1 2003/09/11 02:05:45 decibel Exp $
#
# Returns how many rows are in the master table for a given date
#
# Arguments:
#	Project
#	Date
#
# Returns:
#	Rowcount

select count(*) from ${1}_master where date = \\'${2}\\'
# turn off header and rows affected output
go -f -h
