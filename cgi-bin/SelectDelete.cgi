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
my $own_projects=$HM->AllProjects($user_id,'own',$unique_id,'allow uncompleted');
my @projects=map {$_->[0]} @$own_projects;
$HM->PegOut("You don't own any projects.") unless @projects;
my $analyses=$HM->AllAnalyses($user_id,'own',$FORM{unique_id});
my %analyses2projects;
foreach (@$analyses){
	my $project_no=shift @$_;
	push @{$analyses2projects{$project_no}},$_;
}

$HM->StartOutput("HomozygosityMapper: Delete $species projects and analyses",
	{	'HomozygosityMapperSubtitle'=>"Delete $species projects and analyses",
		'no_heading'=>1});
print qq !<form action="/HM/Delete.cgi" method="post" enctype="multipart/form-data">
<input type="hidden" name="species" value="$species">\n!;
print qq !<input type="hidden" name="unique_id" value="$unique_id">\n! if $unique_id;
my %altcolour=(-1=>'bgcolor="#E6E6E6"',1=>'');
my $colour=1;
print qq !<br><table cellpadding="10" width="800" align="center">
<tr><td></td>
<td><A HREF="/HomozygosityMapper/documentation.html#deletedata" TARGET="doc">help</A>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<A HREF="/tutorial.html#delete" TARGET="doc">tutorial</A></td></tr>\n!;
print qq !<TR><td><INPUT type="submit" name="submit" value="Delete selected projects and/or analyses."></td></tr>\n!;
#
foreach my $projectref (@$own_projects){
	my $vcfinfo=($projectref->[4]?'(VCF, build'.$projectref->[4].')':'');
	$projectref->[6]=~s/\s+00:00:00//;
	print qq !<TR><td $altcolour{$colour}>
	<b><INPUT type="checkbox" name="project_!.$projectref->[0].qq!" value="1">
	$projectref->[1]</b>  $vcfinfo date: $projectref->[6] !.
	($projectref->[7]?"(approx. $projectref->[7] genotypes)":'')."<br>\n";

	foreach my $analysisref (@{$analyses2projects{$projectref->[0]}}){
		$analysisref->[12]=~s/\s+00:00:00//;
	#	my $ddd=join (", ",@$projectref);
		print qq !
			<table cellpadding="2">
			<TR>
				<td width="30" style="valign: top;"> <div align="center"><INPUT type="checkbox" name="analysis_!.$projectref->[0].'v'.$analysisref->[0].qq !" value="1"></DIV></td>
				<td>
	 				<b>$analysisref->[2]</b>:&nbsp;&nbsp;$analysisref->[3]<br>
	 				<small>frequencies: $analysisref->[5], max block length: $analysisref->[6], date: $analysisref->[12] - $analysisref->[8] markers</small>
	 			</td>
	 		</tr>
	 		</table>\n!;
	}
	print "</td></TR>\n";
	$colour*=-1;
}
print qq !<tr><td><INPUT type="submit" name="submit" value="Delete selected projects and/or analyses."></td>
<td><A HREF="/HomozygosityMapper/documentation.html#deletedata" TARGET="doc">help</A>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<A HREF="/tutorial.html#delete" TARGET="doc">tutorial</A></td></tr></table></FORM>!;
$HM->EndOutput();	
