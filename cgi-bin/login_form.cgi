#!/usr/bin/perl
#!perl

use strict;
use HTML::Entities;
use CGI qw(:standard);
use lib '/www/lib/';
use HomozygosityMapper;

my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $user=$HM->Authenticate(@FORM{qw !userid password!});
$HM->StartOutput("HomozygosityMapper - Login",	{	'HomozygosityMapperSubtitle'=>"Please log in.",
		'no_heading'=>1});
print qq ~
<form action="/HM/login.cgi" method="post" enctype="multipart/form-data">
	<input type="hidden" name="species" value="$FORM{species}">
	<table width="700" align="center" cellspacing="20">
	<tr>
			<td style="line-height: 9pt;" colspan="2">&nbsp;</td>
	</tr>
	<tr>
		<td>user ID </td>
		<td><input name="userid" size="40" maxlength="40" type="text"></td>
	</tr>
	<tr>
		<td>password</td>
		<td><input type="password" size="40" maxlength="40" name="password">
		</td>
	</tr>
	<tr>
		<td>&nbsp;</td>
		<td>&nbsp;
		</td>
	</tr>
	<tr>
		<td colspan="2">Your browser <b>must</b> accept cookies for a personal login.
		</td>
	</tr>
	<tr>
		<td>&nbsp;</td>
		<td><br>
		  <input name="Submit" value="Submit" type="submit">
		  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <a href="http://www.homozygositymapper.org/documentation.html#login" target="doc">help</a> </td>
	  </tr>
  </table>
</form>~;
$HM->EndOutput();


