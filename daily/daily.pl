#!/usr/bin/perl -w -I../global
#
# $Id: daily.pl,v 1.9 2000/08/16 19:32:06 nugget Exp $

use strict;
$ENV{PATH} = '/usr/local/bin:/usr/bin:/bin:/opt/sybase/bin';

#$0 =~ /(.*\/)([^\/]+)/;
#my $cwd = $1;
#my $me = $2;
#chdir $cwd;

use statsconf;
use stats;

my $yyyy = (gmtime(time-3600))[5]+1900;
my $mm = (gmtime(time-3600))[4]+1;
my $dd = (gmtime(time-3600))[3];
my $hh = (gmtime(time-3600))[2];
my $datestr = sprintf("%04s%02s%02s-%02s", $yyyy, $mm, $dd, $hh);

my $respawn = 0;

my $workdir = "./workdir/";

if(!$ARGV[0]) {
  stats::log("stats",132,"Some darwin just called hourly.pl without supplying a project code!");
  die;
}
my $project = $ARGV[0];

stats::log($project,1,"Beginning daily processing routines");

if(!$statsconf::prids{$project}) {
  stats::log($project,131,"I've never heard of project class $project!");
  die;
} else {
  my $qs_update = "select convert(char(8),max(DATE),112) from Platform_Contrib where 2=1";

  my @pridlist = split /:/, $statsconf::prids{$project};
  for (my $i = 0; $i < @pridlist; $i++) {
    my $project_id = int $pridlist[$i];
    $qs_update = "$qs_update or PROJECT_ID = $project_id";
  
    sqsh("retire.sql $project_id");
    sqsh("dy_appendday.sql $project_id");
    sqsh("em_rank.sql $project_id");
    sqsh("tm_rank.sql $project_id");
    sqsh("dy_dailyblocks.sql $project_id");
    sqsh("audit.sql $project_id");

    sqsh("clearday.sql $project_id");
    system "sudo pcpages_$project $project_id";
    sqsh("backup.sql $project_id");
  }
  open TMP, ">/tmp/sqsh.tmp.$project";
  print TMP "$qs_update\ngo";
  close TMP;
  my $lastdaynewval = `sqsh -S$statsconf::sqlserver -U$statsconf::sqllogin -P$statsconf::sqlpasswd -w999 -w 999 -h -i /tmp/sqsh.tmp.$project`;
  $lastdaynewval =~ s/[^0123456789]//g;
  unlink "/tmp/sqsh.tmp.$project";
  stats::lastday($project,$lastdaynewval);
}

sub sqsh {
  my ($sqlfile) = @_;

  my $bufstorage = "";
  my $sqshsuccess = 0;
  my $starttime = (gmtime);
  my $secs_start = int `date "+%s"`;
  open SQL, "sqsh -S$statsconf::sqlserver -U$statsconf::sqllogin -P$statsconf::sqlpasswd -w999 -i $sqlfile |";

  if(!<SQL>) {
    stats::log($project,131,"Failed to launch $sqlfile -- aborting.");
    die;
  }
  while (<SQL>) {
    my $ts = sprintf("[%02s:%02s:%02s]",(gmtime)[2],(gmtime)[1],(gmtime)[0]);
    my $buf = $_;
    chomp $buf;
    stats::log($project,0,$buf);
    $bufstorage = "$bufstorage$ts $_";
    if( $_ =~ /^Msg/ ) {
      $sqshsuccess = 1;
    }
    if( $_ =~ /ERROR/ ) {
      $sqshsuccess = 1;
    }
  }
  close SQL;
  if( $sqshsuccess > 0) {
    stats::log($project,131,"$sqlfile puked  -- aborting.  Details are in $workdir\sqsh_errors");
    open SQERR, ">$workdir\sqsh_errors";
    print SQERR "$bufstorage";
    close SQERR;
    die;
  }
  my $secs_finish = int `date "+%s"`;
  my $secs_run = $secs_finish - $secs_start;
  stats::log($project,1,"$sqlfile completed successfully ($secs_run seconds)");
}

