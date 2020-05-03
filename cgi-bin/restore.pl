use strict;
$|=1;
use lib '/www/lib/';
use HomozygosityMapper;
use Data::Dumper;
my $tmpdir='/tmp/';
my $htmltmpdir='/temp/';

my %columns= (
	'samples'=>[qw !sample_no sample_id!],
	'analysis_samples'=>[qw !sample_no affected!],
	'genotypes'=>[qw !dbsnp_no sample_no genotype block_length!],
	'results'=>[qw !dbsnp_no hom_freq hom_freq_ref score!],
	'vcf_genotypes'=>[qw !sample_no chromosome position genotype block_length!],
	'vcf_results'=>[qw !chromosome position hom_freq hom_freq_ref score!]
	);


my %FORM;
foreach (@ARGV){
	my ($param,$value)=split /=/;
	$FORM{$param}=$value;
}
my $project_no=$FORM{project_no};
my $project_name=$FORM{project_name};

my $vcfbuild=$FORM{vcfbuild};
if ($vcfbuild) {
	
	$columns{genotypes}=$columns{'vcf_genotypes'};
	$columns{results}=$columns{'vcf_results'};
}
my $HM=new HomozygosityMapper($FORM{species});
my $targetfolder=$tmpdir.$FORM{target_folder}.'/';
my $outputfile=$tmpdir.$FORM{html_output};
$HM->StartOutput("Restoring project $project_name...",
	{	refresh=>[$htmltmpdir.$FORM{html_output},5],
		filename=>$outputfile,
		no_heading=>1,
		'HomozygosityMapperSubtitle'=>"Restoring project $project_name...",
	});
	


print "<hr>";
print "This page will be updated in 10 seconds. Pressing RELOAD is safe now...<br>";


my $filehandle;

if ($FORM{compression} eq 'zip'){
	my $zipfile=$FORM{filename}.".zip";
	print "Unzipping zip file $zipfile...\n";
	print "<pre>unzip $zipfile -q -d $targetfolder</pre>\n";
	rename $FORM{filename},$zipfile;
	system (qq !unzip -q $zipfile -d $targetfolder!);
	unlink $zipfile;
	#$FORM{filename}=$FORM{genotypes_file};
}

my $fn=$FORM{filename};

my $dbh=$HM->{dbh};
my $user_id=$HM->Authenticate;
my $unique_id=$FORM{"unique_id"} || 0;
my $genotypestable=($vcfbuild?'vcf':'')."genotypes_".$project_no;
my $samplestable= "samples_".$project_no;

CheckFile('Genotypes',$genotypestable);
CheckFile('Samples',$samplestable);

my $analyses=$dbh->prepare ("SELECT analysis_no FROM ".$HM->{prefix}."analyses WHERE project_no=?") || die2($DBI::errstr);
$analyses->execute($FORM{project_no}) || die2($DBI::errstr);
my $r_analyses=$analyses->fetchall_arrayref || die2($DBI::errstr);


foreach (@$r_analyses) {
	my $analysis_no=$_->[0];
	my $resultstable=($vcfbuild?'vcf':'')."results_".$project_no.'v'.$analysis_no;
	my $samplestable="samples_".$project_no.'v'.$analysis_no;  
	#print "Analysis # $analysis_no, results $resultstable, samples $samplestable<br>\n";
	print "Analysis # $analysis_no, checking for samples and results tables<br>\n";
	CheckFile('Results',$resultstable);
	CheckFile('Samples',$samplestable);
}

$HM->{project_no}=$project_no;
$HM->{new}=1;
$HM->CreateSamplesTable;

RestoreTable($samplestable,'samples');
if ($vcfbuild) {
	$HM->CreateGenotypesTableVCF('no_raw');
} else {
	$HM->CreateGenotypesTable('no_raw');
}
RestoreTable($genotypestable,'genotypes');
foreach (@$r_analyses) {
	my $analysis_no=$_->[0];
		my $resultstable=($vcfbuild?'vcf':'')."results_".$project_no.'v'.$analysis_no;
	my $samplestable="samples_".$project_no.'v'.$analysis_no;  
		$HM->CreateSamplesAnalysisTable($analysis_no);
	my $rtable='';
	if ($vcfbuild) {
		$HM->CreateResultsTableVCF($analysis_no);
	}
	else {
		$HM->CreateResultsTable($analysis_no);
	}

	RestoreTable($samplestable,'analysis_samples');
	RestoreTable( $resultstable,'results');

}

my $restore_analyses=$dbh->prepare ("UPDATE ".$HM->{prefix}."analyses SET archived=NULL WHERE project_no=?") || die2($DBI::errstr);
$restore_analyses->execute($FORM{project_no}) || die2($DBI::errstr);
my $restore_project=$dbh->prepare ("UPDATE ".$HM->{prefix}."projects SET archived=NULL WHERE project_no=?") || die2($DBI::errstr);
$restore_project->execute($FORM{project_no}) || die2($DBI::errstr);
$dbh->commit();


$HM->StartOutput("Project $project_name successfully restored!",
	{	
		filename=>$outputfile,
		no_heading=>1,
		'HomozygosityMapperSubtitle'=>"Project $project_name successfully restored!",
	});
print qq !<h2 class="green">Done.</h2>!;
my $restore_link="/HM/SelectRestore.cgi?species=$FORM{species}";
$restore_link.="&unique_id=$unique_id" if $unique_id;
print qq *<p><A HREF="$restore_link">Restore further projects.</A></p>
	<p><A HREF="/HomozygosityMapper/$FORM{species}/index.html">Start page.</A></p>*;
$HM->EndOutput;	

sub CheckFile {
	my ($name,$file)=@_;
	print "<small>trying to find $name ($file) in your archive...<br></small>\n";
	$HM->PegOut("$name file not in archive, cannot proceed.") unless -e $targetfolder.$FORM{species}.$file.'.txt';
}

sub RestoreTable {
	my ($tablename,$tabletype)=@_;
	 
	my $file=$targetfolder.$FORM{species}.$tablename.'.txt';
	print "<small>restoring $tablename...<br></small>\n";
	my $sql="INSERT INTO ".$HM->{data_prefix}."$tablename (".join (",",@{$columns{$tabletype}}).") VALUES (".join (",",("?") x @{$columns{$tabletype}}).")";
	print "<pre>$sql</pre>\n";
	my $sth=$dbh->prepare($sql) || $HM->PegOut('error',$DBI::errstr);
	open (IN,'<',$file) || $HM->PegOut($!);
	$_=(<IN>);
	my $i=0;
	while (<IN>) {
		chomp;
		$i++;
		my @fields=map {(length $_?$_:undef)} split /\t/;
		
		$sth->execute (@fields) || $HM->PegOut('error2',join (",",@fields)."\n".$DBI::errstr);
	}
	close IN;
	print "<small>$i tuples inserted.<br></small>\n";

}



__END__


/usr/bin/perl /www/HomozygosityMapper/cgi-bin/restore.pl vcfbuild= user_login=dominik target_folder=HM_temp_1464362410_1620 html_output=HM_temp_1464362410_1620.html project_no=65 compression=zip filename=/tmp//CGItemp14020 project_name=DIN> /tmp/deleteme925987txt

my @tablenames=(( $vcf_projects{$project_id}?'vcf':'')."results_".$analysis2project, 
		"samples_".$analysis2project);
		foreach my $tablename (@tablenames) {
			my $q_sth=$dbh->prepare ("SELECT * FROM ".$HM->{data_prefix}.$tablename) 
				|| $HM->die2("ERROR","Could not query table $tablename", $DBI::errstr);
			my $drop_sth=$dbh->prepare ("DROP TABLE ".$HM->{data_prefix}.$tablename) 
				|| $HM->die2("ERROR","Could not archive table $tablename", $DBI::errstr);
			ExportData($q_sth,$drop_sth,$tablename);
		}

open ($filehandle,'<',$fn) || $HM->PegOut("Could not open file: $!");
my $output=[];

if ($FORM{chip_no} eq 'VCF' ){
	$output=$HM->ReadVCF($filehandle,$FORM{min_cov},$FORM{genotype_source});
}
elsif ($HM->{chip_manufacturer}=~/Illumina/i){
	if ($HM->{species} eq 'human' and $FORM{chip_no} >=11 ){
		$HM->{markers_table}='hm.markers_'.$FORM{chip_no} if $HM->{new};
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
	if ($HM->{species} eq 'human'){
		$HM->{markers_table}='hm.markers_'.$FORM{chip_no} if $HM->{new};
	}
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


unlink $tmpdir.$FORM{html_output} || $HM->PegOut ($DBI::errstr);
$HM->StartOutput("Genotypes were written to DB!",{filename=>$tmpdir.$FORM{html_output}, refresh=>[$htmltmpdir.$FORM{html_output},25]});
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
my $link="http://www.homozygositymapper.org/HM/AnalysisSettings.cgi?species=$FORM{species}&project_no=$HM->{project_no}";
if ($secret_key){
	$link.="&unique_id=$secret_key";
	print qq!Please save this link <A HREF="$link">$link</A> to analyse your private data later.<br>!;
}

print qq!<p><A HREF="$link">Analyse your genotypes.</A></p>!;
print "<br>Uploaded file deleted from hard disk.<br>";

$HM->EndOutput();
