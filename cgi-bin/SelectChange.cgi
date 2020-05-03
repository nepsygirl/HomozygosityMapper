#!/usr/bin/perl
#!perl
use strict;
use CGI;
use lib '/www/lib/';
use HomozygosityMapper;
my $cgi=new CGI;
my $species=$cgi->param('species');
my $HM=new HomozygosityMapper($species);
my $user_id=$HM->Authenticate();
my %FORM=$cgi->Vars();
my $unique_id=$FORM{unique_id} || 0;


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


$HM->StartOutput("HomozygosityMapper: Change names of $species projects and analyses",
	{	'HomozygosityMapperSubtitle'=>"Change names of $species projects and analyses",
		'no_heading'=>1});

print qq!<form action="/HM/Change.cgi" method="post" enctype="multipart/form-data">
<input type="hidden" name="species" value="$species">
<input type="hidden" name="project_no" value="$project_no">\n!;
print qq!<input type="hidden" name="analysis_no" value="$analysis_no">\n! if $analysis_no;
print qq!<input type="hidden" name="unique_id" value="$unique_id">\n! if $unique_id;

print qq!<table border="0" cellpadding="5" align="center">
<tr><td>project name</td><td><input type="text" name="project_name" value="$HM->{project_name}"></td></tr>!;
print qq!<tr><td>analysis name</td><td><input type="text" name="analysis_name" value="$HM->{analysis_name}"></td></tr>! if $HM->{analysis_name};
print qq!<tr><td></td><td><input type="submit" value="update"></td></tr></table></FORM>!;

$HM->EndOutput();	

__END__


my %altcolour=(-1=>'bgcolor="#E6E6E6"',1=>'');
my $colour=1;
print qq!<br><table cellpadding="10" width="800" align="center">
<tr><td></td>
<td><A HREF="/HomozygosityMapper/documentation.html#changenames" TARGET="doc">help (not yet)</A>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<A HREF="/tutorial.html#change" TARGET="doc">tutorial  (not yet)</A></td></tr>\n!;
foreach my $projectref (@$own_projects){
	my $vcfinfo=($projectref->[4]?'(VCF, build'.$projectref->[4].')':'');
	print qq!<tr><td $altcolour{$colour}>
	<b><INPUT type="checkbox" name="project_!.$projectref->[0].qq!" value="1">
	$projectref->[1]</b>  $vcfinfo<br>
	!;
	foreach my $analysisref (@{$analyses2projects{$projectref->[0]}}){
		
		print qq!
			<table cellpadding="2">
			<tr>
				<td width="30" style="valign: top;"> <div align="center"><INPUT type="checkbox" name="analysis_!.$projectref->[0].'v'.$analysisref->[0].qq!" value="1"></DIV></td>
				<td>
	 				<b>$analysisref->[2]</b>:&nbsp;&nbsp;$analysisref->[3]<br>
	 				<small>frequencies: $analysisref->[5], max block length: $analysisref->[6]</small>
	 			</td>
	 		</tr>
	 		</table>\n!;
	}
	print "</td></tr>\n";
	$colour*=-1;
}
print qq!<tr><td><INPUT type="submit" name="submit" value="Delete selected projects and/or analyses."></td>
<td><A HREF="/HomozygosityMapper/documentation.html#deletedata" TARGET="doc">help</A>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<A HREF="/tutorial.html#delete" TARGET="doc">tutorial</A></td></tr></table></FORM>!;
