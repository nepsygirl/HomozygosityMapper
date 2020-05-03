#!/usr/bin/perl
$|=1;

use strict;
use CGI;
use GD;
use lib '/www/lib';
use HomozygosityMapper;

my $cgi=new CGI;
my $tempdir=($^O=~/win32/i?'t:/www/':'/tmp/');
my %FORM=$cgi->Vars();
$FORM{threshold}='0.8' unless $FORM{threshold};
$FORM{build}=37 unless $FORM{build};
my $unique_id=$FORM{"unique_id"} || 0;
my $HM=new HomozygosityMapper($FORM{species});

my $user_id=$HM->Authenticate;
my $snp_prefix=($HM->{species} && $HM->{species} ne 'human'?'#':'rs');
my ($analysis_no)=$cgi->param('analysis_no');
$HM->{analysis_no}= $analysis_no;
$FORM{analysis_no}= $analysis_no;
$HM->PegOut("No analysis selected!") unless $analysis_no;
$HM->QueryAnalysisName($analysis_no);
my $project_no=$HM->{project_no};
if ($HM->{marker_count}>10000000 && ! $FORM{chromosome}) {
	my $linkout=join ("&",map {"$_=$FORM{$_}"} keys %FORM);
#	print $cgi->redirect("http://www.homozygositymapper.org/HM/ShowRegionOverview.cgi?project_no=$project_no&analysis_no=$analysis_no");
	print $cgi->redirect("http://www.homozygositymapper.org/HM/ShowRegionOverview.cgi?".$linkout);
	exit 0;	
}


my $margin=$HM->SetMargin;


$HM->PegOut("No project selected!") unless $project_no;
$HM->PegOut("Project unknown!") unless $HM->{project_name};
$HM->PegOut("No access to this project! *") unless $HM->CheckProjectAccess($user_id,$project_no,$unique_id);

if ($HM->{vcf} && $FORM{build}==36) {
	$HM->PegOut("VCF projects cannot be converted to b36.3!");
}
my $out=(join (",",%FORM));
# die  if $analysis_no==8585;

my $b36_link='/HM/ShowRegion.cgi?build=36';
foreach my $key (keys %FORM) {
	next if $key eq 'build';
	$b36_link.='&'.$key.'='.$FORM{$key} if length $FORM{$key};
}



my %startpos_chr;
my $startpos=0;





my $sql='';
if ($HM->{vcf}){
	$sql="SELECT chromosome, position, score FROM
	$HM->{data_prefix}vcfresults_".$project_no."v".$analysis_no." r WHERE  ";
}
else {
	$HM->{markers_table}='marker_position_36' if $FORM{build}==36;
	$sql="SELECT chromosome, position, score FROM
	$HM->{markers_table} m, $HM->{data_prefix}results_".$project_no."v".$analysis_no." r WHERE m.dbsnp_no=r.dbsnp_no AND ";
}
my @condition_values;
if ($FORM{chromosome}){
	$sql.=" chromosome=?";
	push @condition_values,$FORM{chromosome};
	if ($FORM{start_pos}){
		$sql.=" AND position>=?";
		push @condition_values,$FORM{start_pos};
	}
	if ($FORM{end_pos}){
		$sql.=" AND position<=?";
		push @condition_values,$FORM{end_pos};
	}
}
else {
	$sql.='chromosome <= '.($HM->{max_chr});
}
# vcfresults_203455v56271
$sql.=" ORDER BY chromosome, position";
my $query=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Did you analyse your project?",{text=>[$sql,$DBI::errstr]});

$query->execute(@condition_values) ||  $HM->PegOut ("Did you analyse your project?",{text=>[$sql,$DBI::errstr]});

my $results=$query->fetchall_arrayref || $HM->PegOut ($DBI::errstr);

$HM->PegOut("Nothing found.") unless @$results;
$HM->PegOut("Only one marker!") unless scalar @$results>1;
print "Content-Type: text/plain\n\n";

print join ("\t",qw /chromosome position score/),"\n";
foreach my $tuple (@$results){
	print join ("\t",@$tuple),"\n";
}
exit 0;

__END__
