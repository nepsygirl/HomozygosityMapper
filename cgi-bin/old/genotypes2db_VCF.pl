use strict;
use Data::Dumper;
$|=1;
use lib '/www/lib/';
use HomozygosityMapperVCF;

my $tmpdir=($^O=~/win32/i?'t:/www/':'/tmp/');
my $htmltmpdir='/temp/';

my %FORM;
foreach (@ARGV){
	my ($param,$value)=split /=/;
	$FORM{$param}=$value;
}

my $HM=new HomozygosityMapper($FORM{species});

my $outputfile=$tmpdir.$FORM{html_output};
$HM->StartOutput("Genotypes are written to DB!",
	{	refresh=>[$htmltmpdir.$FORM{html_output},5],
		filename=>$outputfile,
		no_heading=>1,
		'HomozygosityMapperSubtitle'=>'Genotypes are written to DB!',
	});
#$HM->PegOut("Illegal file name: $FORM{filename}") if $FORM{filename}=~/\W/;
#warn "/usr/bin/perl /www/cgi-bin/HM/genotypes2db.pl ".join (" ",map {"$_=$FORM{$_}"} keys %FORM)."<br>";
#foreach (keys %FORM){
#	print "$_ -> $FORM{$_}<BR>\n";
#}
print "<hr>";
print "This page will be updated in 5 seconds. Pressing RELOAD is safe now...<br>";
#open (STDERR,'>>',$tmpdir.$FORM{html_output}) || $HM->PegOut ("Could not write to log file: $!");
#print STDERR "/usr/bin/perl /www/cgi-bin/HM/genotypes2db.pl ".join (" ",map {"$_=$FORM{$_}"} keys %FORM)."\n";
if (length $FORM{project_name} && $FORM{project_no}){
	$HM->PegOut("Please either select an existing project or enter a new one.");
}
elsif (length $FORM{project_name}==0 && ! $FORM{project_no}){
	$HM->PegOut("Please select an existing project or enter a new one.");
}
my @errors;
foreach my $param (qw/chip_no user_login filename html_output/){
	push @errors,$param.' not set!' unless $FORM{$param};
}

my $secret_key='';
if ($FORM{"user_login"} eq 'guest' && $FORM{"access_restricted"}) {
	my @chars=(0..9,'A'..'Z','a'..'z');
	my $string='';
	for my $i (0..29){
		$secret_key.=$chars[int(rand(@chars))];
	}
}

if ($FORM{project_no}){
	$HM->PegOut("Adding private data to a public project is not possible") if $secret_key;
	$HM->PegOut("Adding data to a VCF project is not possible") if $FORM{chip_no} eq 'VCF';
	$HM->CheckProjectAccess($FORM{"user_login"},$FORM{project_no});
	print "Access granted!\n";
}
else {
	my $vcfbuild=37 if $FORM{chip_no} eq 'VCF';
	$HM->QueryProject($FORM{project_name},'new',$FORM{"user_login"},$FORM{"access_restricted"},$secret_key,$vcfbuild);
	print "Project $HM->{project_no} created! $vcfbuild<br>\n";
	$HM->{new}=1;
}

if ($FORM{chip_no} eq 'VCF' ){
	print "VCF<br>\n";
	$HM->CreateGenotypesTableVCF;
	print "GT table created.<br>\n";
	$HM->{chip_name}='VCF';
}
else {
	unless ($HM->CheckChipNumber($FORM{chip_no})){
		$HM->PegOut("Genotypes could not be added:",{list=>["chip $FORM{chip_no} unknown"]});
	}
	$HM->CreateGenotypesTable;
}

my $filehandle;

if ($FORM{compression} eq 'gz'){
	my $gzipfile=$FORM{filename}.".gz";
	print "Unzipping gzip file $gzipfile...\n";
	rename $FORM{filename},$gzipfile;
	system (qq!gunzip  $gzipfile!);
	unlink $gzipfile;
}
elsif ($FORM{compression} eq 'zip'){
	my $zipfile=$FORM{filename}.".zip";
	print "Unzipping zip file $zipfile...\n";
	rename $FORM{filename},$zipfile;
	system (qq!unzip -p $zipfile > $FORM{filename}!);
	unlink $zipfile;
	#$FORM{filename}=$FORM{genotypes_file};
}

my $fn=$FORM{filename};
print "Your chip: $HM->{chip_name} [$HM->{chip_manufacturer}]<br>\n";
print "Reading genotypes from $fn...<br>\n";
open ($filehandle,'<',$fn) || $HM->PegOut("Could not open file: $!");
my $output=[];

if ($FORM{chip_no} eq 'VCF' ){
	$output=$HM->ReadVCF($filehandle,$FORM{min_cov});
}
elsif ($HM->{chip_manufacturer}=~/Illumina/i){
	if ($FORM{chip_no} >=11 && $FORM{chip_no} <=14){
		$HM->QueryMarkers();
	}
	if ($HM->{species} ne 'human'){
		print "Now querying your $HM->{species} chip for markers... This may take some seconds.<br>";
		$HM->QueryMarkers();
		if ($FORM{real_genotypes}){
			$output=$HM->ReadIllumina_NonHuman_NF($filehandle);
		}
		else {
			$output=$HM->ReadIllumina_NonHuman($filehandle);
		}
	}
	elsif ($FORM{real_genotypes}){
		$output=$HM->ReadIllumina_NF($filehandle);
	}
	else {
		$output=$HM->ReadIllumina($filehandle);
	}
}
elsif ($HM->{chip_manufacturer}=~/Affy/i){
	print "Now querying your chip for markers... This may take some seconds.<br>";
	$HM->QueryMarkers();
	$output=$HM->ReadAffymetrix($filehandle);
}
else {
	$HM->PegOut("Chip unknown!");
}
print "Determining block lengths...<br>\n";
if ($FORM{chip_no} eq 'VCF'){
	$HM->BlockLengthVCF();
	$HM->DeleteTable('vcfgenotypesraw');
}
else {
	$HM->BlockLength();
	$HM->DeleteTable('genotypesraw');
}
print "DONE!";

print "Committing...<br>\n";
$HM->Commit || $HM->PegOut ($DBI::errstr);
$HM->Rollback || $HM->PegOut ($DBI::errstr);
unlink $tmpdir.$FORM{html_output} || $HM->PegOut ($DBI::errstr);
$HM->StartOutput("Genotypes were written to DB!",{filename=>$tmpdir.$FORM{html_output}});
print qq!<strong class="red">DONE.</strong><br>\n!;
print join ("<br>",@$output),'<hr>';
print "Now cleaning up...<br>";
if ($FORM{chip_no} eq 'VCF'){
	$HM->Vacuum('vcfgenotypes');
}
else {
	$HM->Vacuum('genotypes');
}
unlink $FORM{filename};
my $link="http://www.homozygositymapper.org/cgi-bin/HM/AnalysisSettings".($HM->{vcf}?'VCF':'').".cgi?species=$FORM{species}&project_no=$HM->{project_no}";
if ($secret_key){
	$link.="&unique_id=$secret_key";
	print qq!Please save this link <A HREF="$link">$link</A> to analyse your private data later.<br>!;
}

print qq!<p><A HREF="$link">Analyse your genotypes.</A></p>!;
print "<br>Uploaded file deleted from hard disk.<br>";

$HM->EndOutput();
