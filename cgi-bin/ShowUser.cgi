#!/usr/bin/perl
#!perl


use strict;
use CGI;
use lib '/www/lib';
use HomozygosityMapper;
my $cgi=new CGI();
my $ajax=$cgi->param("via_ajax") || 0;
my $species=$cgi->param("species");
my $HM=new HomozygosityMapper($species);
my $user_id=$HM->Authenticate;
print "Content-Type: text/html\n\n";
unless ($user_id eq 'guest'){
	print qq!<i>$user_id</i>!;
}
else {
	print qq!<span class="red">logged in as guest - you cannot create private data</span>!;
}
exit 0;

