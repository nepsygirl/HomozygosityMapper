#!/usr/bin/perl
#!perl
$|=1;
use strict;
use CGI;
use lib 'e:/www/lib';
use lib '/www/lib';
use HomozygosityMapper_animals;
my $tmpdir=($^O=~/win32/i?'t:/www/':'/tmp/');

my $HM=new HomozygosityMapper;
my $cgi=new CGI;
exit 0 unless $cgi->param('xfd') eq 'rtg';
print "Content-Type: text/plain\n\n";

foreach my $table (qw/users projects analyses/){
	print "*table*\n";
	my $sql="SELECT * FROM ".$HM->{prefix}.$table;
	my $query_projects=$HM->{dbh}->prepare($sql) || die("$DBI::errstr");
	$query_projects->execute()  || die("APr $DBI::errstr",$sql);
	my $data_ref=$query_projects->fetchall_arrayref;
	foreach (@$data_ref){
		print join ("\t",@$_),"\n";
	}
	print "\n\n";
}
exit 0;
