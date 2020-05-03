#!/usr/bin/perl
use strict;
use HTML::Entities;
use CGI qw(:standard); 
use CGI::Cookie;
use CGI::Carp ('fatalsToBrowser');
use utf8; 
use Encode; 
use lib '/www/lib/';
use HomozygosityMapper;


my $HM=new HomozygosityMapper;
my $user_id=$HM->Authenticate();

$HM->StartOutput ("Login",{no_heading=>1});
if ($user_id eq 'guest') {
	print "not logged in";
}
else {
	print "logged in as <i>$user_id</i>";
}
$HM->EndOutput();
