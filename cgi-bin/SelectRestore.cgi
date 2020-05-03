#!/usr/bin/perl
#!perl
use strict;
use CGI;
use HTML::Template;
use lib '/www/lib/';
use HomozygosityMapper;

my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $user_id=$HM->Authenticate;
my $unique_id=$FORM{"unique_id"} || 0;
my $projectsref=$HM->AllProjects($user_id,'own',$unique_id,0,'allow archived');
$HM->PegOut("No projects accessible for you!") unless ref $projectsref eq 'ARRAY' and @$projectsref>0;

$HM->StartOutput("HomozygosityMapper: Restore archived $FORM{species} data",{
	'HomozygosityMapperSubtitle'=>"Restore archived $FORM{species} data",
	'no_heading'=>1});
print qq !<form action="/HM/Restore.cgi" method="post" enctype="multipart/form-data">
<INPUT type="hidden" name="species" value="$FORM{species}">
<input type="hidden" name="unique_id" value="$unique_id">
<TABLE align="center">!;

foreach (@$projectsref){

	print qq !<TR><td><INPUT type="radio" name="project_no" value="$_->[0]"></td><td>$_->[1]</td></TR>\n!;

}
print qq !<TR><td>ZIP archive</td><td><INPUT type="file" name="filename"></td></TR>
<TR><td></td><td><INPUT type="submit" value="restore"></td></TR>
</table></DIV></FORM>\n!;
$HM->EndOutput();
