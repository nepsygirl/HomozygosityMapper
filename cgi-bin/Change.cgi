#!/usr/bin/perl

use strict;
use lib '/www/lib/';
use HomozygosityMapper;
use CGI;

my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $unique_id=$FORM{unique_id} || 0;
my $user_id=$HM->Authenticate;

my ($analysis_no)=$cgi->param('analysis_no');
my ($project_no)=$cgi->param('project_no');
$HM->PegOut("No analysis or project selected!") unless $analysis_no || $project_no;
if ($analysis_no){
	$HM->QueryAnalysisName($analysis_no) ;
	$HM->PegOut("Project unknown!") unless $HM->{project_name};
	if ($project_no) {
		$HM->PegOut("Data mismatch!") unless $project_no==$HM->{project_no};
	}
else {
	$project_no=$HM->{project_no};
	}
}

$HM->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$project_no,$unique_id);
$HM->PegOut("This is not your project!") unless $user_id eq $HM->{user_login};

my %changed=();
if ($FORM{analysis_no} && $FORM{analysis_name}) {
	my $sql="UPDATE ".$HM->{prefix}."analyses SET analysis_name=? WHERE analysis_no=?" ;
	my $u=$HM->{dbh}->prepare($sql) || $HM->die2($sql, $DBI::errstr);
	$u->execute($FORM{analysis_name}, $FORM{analysis_no})
	 || $HM->die2($sql.'-'.$DBI::errstr);
	$changed{analysis}=1;
}
if ($FORM{project_no} && $FORM{project_name}) {
	my $sql="UPDATE ".$HM->{prefix}."projects SET project_name=? WHERE project_no=? AND user_login=?" ;
	my $u=$HM->{dbh}->prepare($sql)  || $HM->die2($sql, $DBI::errstr);
	$u->execute($FORM{project_name}, $FORM{project_no}, $user_id )
	 || $HM->die2($sql.'-'.$DBI::errstr);
	$changed{project}=1;
}

$HM->Commit if keys %changed;
$HM->StartOutput("HomozygosityMapper: Changed project/analysis name",{
	'HomozygosityMapperSubtitle'=>"Changed project/analysis name",
	'no_heading'=>1});

print "Project title was changed to $FORM{project_name}.<br>" if $changed{project};
print "Analysis title was changed to $FORM{analysis_name}.<br>" if $changed{analysis};
unless (keys %changed) {
	print qq !Nothing changed.<br>!;
}

	

print qq !<p><A HREF="/HomozygosityMapper/index.html">Start page.</A></p>!;

$HM->EndOutput();