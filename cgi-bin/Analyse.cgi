#!/usr/bin/perl
#!perl
use strict;
use CGI;
use CGI::Carp('fatalsToBrowser');
use lib '/www/lib/';
use HomozygosityMapper;
$|=1;
my $tmpdir=($^O=~/win32/i?'t:/www':'/tmp');
my $htmltmpdir='/temp/';
my $cgi=new CGI;
my %FORM=$cgi->Vars();
 

my $filename="HM_anal_".time()."_".int(rand(100000));
$FORM{html_output}=$filename.'.html';

my $HM=new HomozygosityMapper($FORM{species});


my $user_id=$HM->Authenticate;
$FORM{"user_login"}=$user_id ;

my @errors;

if ($FORM{'homogeneity_required'} and ! $FORM{'exclusion_length'}){
	push @errors,"Please specify the length of runs of homozygosity in controls that will exclude regions 
	if you require genetic homogeneity - set the value to -1 if you don't want to exclude regions due to the controls' genotypes";
}
elsif ($FORM{'exclusion_length'}>0 and ! $FORM{'homogeneity_required'}){
		push @errors,"You specified the length of runs of homozygosity in controls that will exclude regions 
		buit didn't check the require genetic homogeneity button";
} 

foreach my $field (qw /project_no analysis_name cases_ids /){
	push @errors,qq *Required parameter <i>$field</i> not set!* unless $FORM{$field};
}

$FORM{cases_ids}=~s/\n/ /gs;
$FORM{controls_ids}=~s/\n/ /gs;
$FORM{cases_ids}=~s/\s+/ /gs;
$FORM{controls_ids}=~s/\s+/ /gs;
my (%cases,%controls)=();
@cases{split /\s*[ ,;]+\s*/,$FORM{cases_ids}}=();
push @errors,"No case specified!" unless keys %cases;
@controls{split /\s*[ ,;]\s*/,$FORM{controls_ids}}=();

foreach my $key (keys %FORM) {
	$FORM{$key}=~s/"/'/g;
}

if ($FORM{allele_frequencies} eq 'controls'){
	push @errors,"No controls specified, how shall I use their frequencies?<br>I can calculate extremely well but I don't have the second sight." unless keys %controls;
}




delete (@FORM{'controls_ids','cases_ids'});
if (keys %controls){
	foreach my $case (keys %cases){
		push @errors,"$case is specified as a case <u>and</u> a control!" if exists $controls{$case};
	}
}
$HM->{project_no}=$FORM{project_no};
$HM->PegOut("$user_id: No access to this project!") unless $HM->CheckProjectAccess($user_id,$FORM{project_no},$FORM{unique_id});
if ($FORM{allele_frequencies} and $HM->{vcf}){
	push @errors,"Can't use allele frequencies for VCF projects. Sorry.";
}
$FORM{limit_block_length} = $HM->BestBlockLengthLimit() unless $FORM{limit_block_length};
$FORM{lower_limit}=0 unless length $FORM{lower_limit};

if ($FORM{lower_limit} > $FORM{limit_block_length}){
	push @errors,"<i>Lower limit</i> = $FORM{lower_limit}, which is higher than <i>limit block length</i> = $FORM{limit_block_length}. Please change one or both values." ;
}
if (@errors){
	$HM->PegOut("The data cannot be analysed because:",	{list=>[@errors]});
}

my %sampleid2no;
my $samplesref=$HM->GetSampleNumbers();
foreach (@$samplesref){
	$sampleid2no{$_->[1]}=$_->[0];
}
foreach my $sample (keys %cases,keys %controls){
	push @errors,"Sample $sample does not exist" unless $sampleid2no{$sample};
}
if (@errors){
	push @errors,"Available samples are:<br>->".join (",",keys %sampleid2no)."<-";
	$HM->PegOut({	title=>"The data cannot be analysed because:",	list=>[@errors]});
}
$FORM{cases}=join (",",@sampleid2no{keys %cases});
$FORM{controls}=join (",",@sampleid2no{keys %controls});

my $html_target=$htmltmpdir.$FORM{html_output};
$HM->StartOutput("Your analysis is performed...!",
	{	refresh=>[$html_target,1],
		no_heading=>1,
		css=>'/HomozygosityMapper/css.css', 	
		'HomozygosityMapperSubtitle'=>'Analysis is performed...',
	});

print qq !<h3 class="red">DON'T TRY TO RELOAD THIS PAGE, USE THE HYPERLINK BELOW INSTEAD</h3>\n!; #'
print qq !<A HREF="$html_target">see status</A><br>\n!;
print "</BODY></HTML>";
undef $HM;
close (STDOUT);
close (STDIN);
unless (open F, "-|") {
	open STDERR, ">&=1";
	exec ("/usr/bin/perl /www/HomozygosityMapper/cgi-bin/Analyse.pl \"".join ('" "',map {"$_=$FORM{$_}"} keys %FORM).'"');
	die "Cannot execute traceroute: $!";
}
exit 0;
