#!/usr/bin/perl
use Data::Dumper;
use strict;
use lib '/www/lib/';
use HomozygosityMapper;
use CGI;

my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $unique_id=$FORM{unique_id} || 0;
my $user_id=$HM->Authenticate;

my $own_projects=$HM->AllProjects($user_id,'own',$unique_id,'allow uncompleted');
my %projects;
my %vcf_projects;
my %vcf_analyses;
foreach (@$own_projects){
	$projects{$_->[0]}=$_->[1];
	$vcf_projects{$_->[0]}="(VCF, build $_->[4])" if $_->[4];
}
my $analyses=$HM->AllAnalyses($user_id,'own',$unique_id);
my %analyses;
foreach (@$analyses){
	$analyses{$_->[1]}=$_->[2].':'.$_->[3];
	$vcf_analyses{$_->[1]}="(VCF, build $_->[10])" if $_->[10];
}
my %projects2delete;
@projects2delete{grep s/project_//, keys %FORM}=();
my %projects2analyses2delete;
@projects2analyses2delete{grep s/analysis_//, keys %FORM}=();
my %analyses2delete;
@analyses2delete{grep s/analysis_\d+v//, keys %FORM}=();
unless  (keys %projects2delete || keys %analyses2delete){
	$HM->die2("You did not select anything to delete...");
}
#if (keys %projects2delete>2){
#	$HM->die2("Please do not delete more than 2 projects at one time.");
#}
#if (keys %analyses2delete>6 and ! $FORM{overridelimit}){
#	$HM->die2("Please do not delete more than 6 analyses at one time.");
#}
foreach (@$analyses){
	next unless exists $projects2delete{$_->[0]};
	$analyses2delete{$_->[1]}=1 unless exists $analyses2delete{$_->[1]};
	$projects2analyses2delete{$_->[0].'v'.$_->[1]}=1 unless exists $projects2analyses2delete{$_->[0].'v'.$_->[1]};
}
foreach my $project_no (keys %projects2delete){
	$HM->PegOut("User '$user_id': No access to project $project_no",Dumper(\%projects)) unless exists $projects{$project_no};
}
foreach my $analysis_no (keys %analyses2delete){
	$HM->PegOut("User '$user_id': No access to analysis $analysis_no") unless exists $analyses{$analysis_no};
}

unless ($FORM{confirmed}){
	$HM->StartOutput("HomozygosityMapper: Confirm deletion of your $FORM{species} data",{
	'HomozygosityMapperSubtitle'=>"Confirm deletion of your $FORM{species} data",
	'no_heading'=>1});
	
	print qq!<form action="/HM/Delete.cgi" method="post" enctype="multipart/form-data">
	<input type="hidden" name="species" value="$FORM{species}">
	<table cellpadding="10" width="800" align="center"><tr><td>\n!;
	foreach my $project_no (keys  %projects2delete){
		print "Project: <B>$projects{$project_no}</B>$vcf_projects{$project_no}<br>\n";
		print qq!<INPUT type="hidden" name="project_!.$project_no.qq!" value="1">\n!;
	}
	foreach my $analysis_no (keys %analyses2delete){
		print "Analysis: <B>$analyses{$analysis_no}</B> $vcf_analyses{$analysis_no}";
		print " (because parent project is to be deleted)" if $analyses2delete{$analysis_no};
		print "<br>\n";
	}
	foreach my $analysis2project (keys %projects2analyses2delete){
		print qq!<INPUT type="hidden" name="analysis_!.$analysis2project.qq!" value="1">\n!;
	}
	print qq!<br><INPUT type="submit" value="Confirm deletion." name="confirmed" value="1">\n!;
	print qq!<input type="hidden" name="unique_id" value="$unique_id">\n! if $unique_id;
	print qq!</td></tr></table></form>!;
}
else {
	$HM->StartOutput("HomozygosityMapper: Deleting...",{
	'HomozygosityMapperSubtitle'=>"Deleting your $FORM{species} data...",
	'no_heading'=>1});
	my $delete_project=$HM->{dbh}->prepare(
	"UPDATE ".$HM->{prefix}."projects SET deleted=current_date WHERE project_no=? AND user_login=?") || $HM->die2("SQL error P", $DBI::errstr);
	my $delete_analysis=$HM->{dbh}->prepare(
	"UPDATE ".$HM->{prefix}."analyses  SET deleted=current_date WHERE analysis_no=?") || $HM->die2("SQL error A",$DBI::errstr);
	my $delete_project_permissions=$HM->{dbh}->prepare(
	"DELETE FROM ".$HM->{prefix}."projects_permissions WHERE project_no=?") || $HM->die2("SQL error PP",$DBI::errstr);

	foreach my $analysis_no (keys %analyses2delete){
		$delete_analysis->execute($analysis_no ) || $HM->die2("ERROR","e85 Could not delete analysis $analysis_no:",$DBI::errstr);
	}
	foreach my $analysis2project (keys %projects2analyses2delete){
		my ($project_id)=split /v/,$analysis2project;
#		print "p if $analysis2project $project_id<hr>";
		$HM->{dbh}->do("DROP TABLE ".$HM->{data_prefix}.($vcf_projects{$project_id}?'vcf':'')."results_".$analysis2project) 
			|| $HM->die2("ERROR","Could not delete table ".$HM->{data_prefix}.($vcf_projects{$project_id}?'vcf':'')."results_".$analysis2project, $DBI::errstr);
		$HM->{dbh}->do("DROP TABLE ".$HM->{data_prefix}."samples_".$analysis2project) 
			|| $HM->die2("ERROR","Could not delete table ".$HM->{data_prefix}."samples_".$analysis2project, $DBI::errstr);
	}
	foreach my $project_no (keys  %projects2delete){
		$delete_project_permissions->execute($project_no ) || $HM->die2("ERROR","Could not delete project p $project_no:",$DBI::errstr);
		$delete_project->execute($project_no, $user_id ) || $HM->die2("ERROR","e94 Could not delete project $project_no:",$DBI::errstr);
		$HM->{dbh}->do("DROP TABLE ".$HM->{data_prefix}.($vcf_projects{$project_no}?'vcf':'')."genotypes_".$project_no) 
			|| $HM->die2("ERROR","Could not delete table ".$HM->{data_prefix}.($vcf_projects{$project_no}?'vcf':'')."genotypes_".$project_no, $DBI::errstr);
		$HM->{dbh}->do("DROP TABLE ".$HM->{data_prefix}."samples_".$project_no) 
			|| $HM->die2("ERROR","Could not delete table ".$HM->{data_prefix}."samples_".$project_no, $DBI::errstr);
	}
	$HM->Commit;
	print "<h1>DONE!</h1>";
	my $deletion_link="/HM/SelectDelete.cgi?species=$FORM{species}";
	$deletion_link.="&unique_id=$unique_id" if $unique_id;
	print qq *<p><A HREF="$deletion_link">Delete some more data.</A></p>
	<p><A HREF="/HomozygosityMapper/index.html">Start page.</A></p>*;
}
$HM->EndOutput();