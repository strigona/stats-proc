#!/bin/sh
# $Id: daily.sh,v 1.2 2002/12/21 18:51:39 nerf Exp $

# addlog.sql drops and creates the logdata table each day, and fills it with filtered(filter.pl) data.
# id_lookup.sql creates a table containing an id and an email for each participant.
# movedata.sql moves the valid data from logdata to the table called nodes and creates indecies on nodes.
# donenodes.sql creates the donenodes table, does not put any data in it.
# query3.sql is the big query, fills donenodes with data.

psql -d ogrstats -f addlog.sql
psql -d ogrstats -f id_lookup.sql
psql -d ogrstats -f movedata.sql
psql -d ogrstats -f donenodes.sql
psql -d ogrstats -f query3.sql
