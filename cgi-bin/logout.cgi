#!/usr/bin/perl

use strict;
use HTML::Entities;
use CGI qw(:standard); 
use CGI::Cookie;
use CGI::Carp ('fatalsToBrowser');
use lib '/www/lib/';
use HomozygosityMapper;
my $HM=new HomozygosityMapper;
my $cgi=new CGI;
my $user_id=$HM->Authenticate;
my $cookie1 = new CGI::Cookie(-name=>'HomozygosityMapperAuth',-value=> encode_entities('guest')."=".encode_entities('pw'));	
		print "Set-Cookie: $cookie1\n";	

$HM->StartOutput("Goodbye $user_id.",	{	'HomozygosityMapperSubtitle'=>"Goodbye  $user_id.",
		'no_heading'=>1});
print qq°<br><br><br><h3 align="center">You are now logged out.</h3>
<p align="center">If you discovered bugs or have suggestion, please write an<br>
e-mail to dominik.seelow (at) charite.de.</p>
<p align="center">We appreciate your feedback!</p>
<h2 align="center"><A HREF="/HomozygosityMapper/index.html">Continue.</A></h3>°;

$HM->EndOutput();

