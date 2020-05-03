#!/usr/bin/perl
#!perl
close STDOUT;
close STDIN;
use strict;
$|=1;
use lib '/www/lib/';
use HomozygosityMapperVCF;
my $use_healthy=1;

my $tmpdir=($^O=~/win32/i?'t:/www/':'/tmp/');
my $htmltmpdir='/temp/';


my %FORM;

foreach  (@ARGV){
	my ($param,$value)=split /=/;
	$FORM{$param}=$value;
}
my $HM=new HomozygosityMapper($FORM{species});
my $user_id=$FORM{"user_login"};
my $outputfile=$tmpdir.$FORM{html_output};
$HM->StartOutput("Analysis is performed...",
	{	refresh=>[$htmltmpdir.$FORM{html_output},5],
		filename=>$outputfile,
		no_heading=>1,
		'HomozygosityMapperSubtitle'=>'Analysis is performed',
	}	);
print "This page will be updated in 5 seconds. Pressing RELOAD is safe now...<br>";
#print join (",",%FORM),"<hr>";
$HM->{project_no}=$FORM{project_no};
my $limit=$FORM{limit_block_length} || $HM->BestBlockLengthLimit();
$FORM{'exclusion_length'}=undef if $FORM{'exclusion_length'} and ! $FORM{'homogeneity_required'};
$HM->PegOut("$user_id: No access to this project!") unless $HM->CheckProjectAccess($user_id,$FORM{project_no},$FORM{unique_id});
my @cases=split /\s*[,]\s*/,$FORM{cases};
my @controls=split /\s*[,]\s*/,$FORM{controls};

# GetNextAnalysis
my $analysis_no=$HM->InsertAnalysis([@FORM{qw/project_no analysis_name allele_frequencies analysis_description homogeneity_required lower_limit exclusion_length/},$limit]);
$HM->InsertSamples($analysis_no,[@cases],[@controls]);
my $max_score=0;
if ($FORM{homogeneity_required}){
	$max_score=$HM->AnalyseHomogeneity($analysis_no,$FORM{allele_frequencies},$limit,[@cases],[@controls],$FORM{lower_limit},$FORM{'exclusion_length'});
}
else {
	$max_score=$HM->AnalysePerl($analysis_no,$FORM{allele_frequencies},$limit,[@cases],[@controls],$FORM{homogeneity_required},$FORM{lower_limit});
}

my $insert_maxscore=$HM->{dbh}->prepare("UPDATE $HM->{prefix}analyses SET max_score=? WHERE analysis_no=?") || $HM->PegOut ($DBI::errstr);

$insert_maxscore->execute($max_score,$analysis_no)  || $HM->PegOut('error',{list=>['I-max_score',$DBI::errstr]});
print "Done - committing changes to database...<br>";
$HM->Commit() || $HM->PegOut ($DBI::errstr);
unlink $tmpdir.$FORM{html_output} || $HM->PegOut ($DBI::errstr);
$HM->StartOutput("Analysis done!",{filename=>$tmpdir.$FORM{html_output}});
print qq!<strong class="red">DONE.</strong><br>\n!;

my $link="http://www.homozygositymapper.org//cgi-bin/HM/ShowRegion.cgi?analysis_no=$analysis_no&species=$HM->{species}";
if ($FORM{unique_id}) {
	$link.="&unique_id=$FORM{unique_id}";
	print qq!
	<p class="red">Save these links to your private data:</p>
	View results:<br><A HREF="$link">$link</A><br>
	Delete data: <br>
	<A HREF="http://www.homozygositymapper.org/cgi-bin/HM/SelectDelete.cgi?unique_id=$FORM{unique_id}">http://www.homozygositymapper.org/cgi-bin/HM/SelectDelete.cgi?unique_id=$FORM{unique_id}</A><br>!;
}

print qq°<p><A HREF="$link">Show results.</A></p>°;

$HM->EndOutput;