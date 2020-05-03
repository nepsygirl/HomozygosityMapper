#!/usr/bin/perl
#!perl

use strict;
use HTML::Entities;
use CGI qw(:standard);
use CGI::Cookie;
use lib '/www/lib/';
use HomozygosityMapper;


my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $target=$FORM{'species'} && $FORM{'species'} ne 'human' ? '/'.$FORM{'species'}.'/index.html':'/index.html';
my $user=$HM->Authenticate(@FORM{qw !userid password!});
if ($user eq 'guest'){
	$HM->StartOutput("Login failed",	{	'HomozygosityMapperSubtitle'=>"Login failed.",
		'no_heading'=>1});
		print qq !<h2 align="center">Sorry, this combination of login and passwd is not valid.!;
	}
	else {
		my $cookie1 = new CGI::Cookie(
			-name=>'HomozygosityMapperAuth',
			-value=> encode_entities($FORM{userid})."=".encode_entities($FORM{password}));
		print "Set-Cookie: $cookie1\n";
		my $extra=($FORM{userid} ~~[qw /sshirlee shirlee cemile Veerappa/]?'
				   <h2 class="red" style="text-align: center">Our hard disks are full,
				   you cannot enter new data unless
				   you delete or archive old projects.</h2><br>':'');
		$HM->StartOutput("Welcome $user.",	{	'HomozygosityMapperSubtitle'=>"Welcome $user.",
		'no_heading'=>1});
		print qq !
<br><br><br><h3 align="center">You are now logged in as user <i>$user</i>.</h3>
$extra
<p align="center">For a safe log off, choose log out on HomozygosityMapper's homepage.</p>
<br><br>
<h2 align="center"><A HREF="/HomozygosityMapper/$target">Continue.</A></h3>!; #'
	}
$HM->EndOutput();


