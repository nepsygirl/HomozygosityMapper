#!/usr/bin/perl
$|=1;
use strict;
use lib '/www/lib/';
use HomozygosityMapper;

my @datafiles=();
my %FORM=();
foreach (@ARGV){
	my ($param,$value)=split /=/;
	$FORM{$param}=$value;
}
my $tmpdir='/tmp/';
my $htmltmpdir='/temp/';
my %columns= (
	'samples'=>'sample_no,sample_id',
	'analysis_samples'=>'sample_no, affected',
	'genotypes'=>'dbsnp_no,sample_no,genotype,block_length',
	'results'=>'dbsnp_no,hom_freq,hom_freq_ref,score',
	'vcf_genotypes'=>'sample_no, chromosome, position, genotype, block_length',
	'vcf_results'=>'chromosome, position, hom_freq ,hom_freq_ref, score'
	);

my $export_subfolder;
my $export_folder;
my $outputfile=$tmpdir.$FORM{html_output};
my $HM=new HomozygosityMapper($FORM{species});


	$HM->StartOutput("HomozygosityMapper: archiving...",{
	'HomozygosityMapperSubtitle'=>"archiving your $FORM{species} data...",
	refresh=>[$htmltmpdir.$FORM{html_output},5],
	filename=>$outputfile,
	'no_heading'=>1});

	print "<b>it is now save to press F5/reload - the page is updated automagically though...<br></b>\n";


#$HM->StartOutput("Restoring project $FORM{project_name}...",
#	{	refresh=>[$htmltmpdir.$FORM{html_output},5],
#		filename=>$outputfile,
#		no_heading=>1,
#		'HomozygosityMapperSubtitle'=>"Restoring project $FORM{project_name}...",
#	});

$HM->PegOut("No project selected.") unless $FORM{project};


my $dbh=$HM->{dbh};
my $unique_id=$FORM{unique_id} || 0;
my $user_id=$HM->Authenticate;
#my $user_id='cemile';
my ($project,$project_name)=();

my $own_projects=$HM->AllProjects($user_id,'own',$unique_id,'allow uncompleted');
my $vcf_project;

foreach (@$own_projects){
	next unless $_->[0]==$FORM{project};
	$project=$_->[0];
	$project_name=$_->[1];
	$vcf_project="(VCF, build $_->[4])" if $_->[4];
}
print "<b>Now archiving project <i>$project_name</i></b><br>\n" if $project_name;
if ($vcf_project) {
	$columns{genotypes}=$columns{'vcf_genotypes'};
	$columns{results}=$columns{'vcf_results'};
}
my $analyses=$HM->AllAnalyses($user_id,'own',$unique_id);
my %analyses;
foreach (@$analyses){
	$analyses{$_->[1]}=$_->[2].':'.$_->[3];
}

my %projects2analyses2delete;
@projects2analyses2delete{grep s/analysis_//, keys %FORM}=();
my %analyses2delete;

unless  ($project ){
	$HM->PegOut("You did not select anything to archive...");
}


foreach (@$analyses){
	next unless $project eq $_->[0];
	$analyses2delete{$_->[1]}=1 unless exists $analyses2delete{$_->[1]};
	$projects2analyses2delete{$_->[0].'v'.$_->[1]}=1 unless exists $projects2analyses2delete{$_->[0].'v'.$_->[1]};
}




	$export_subfolder='HM_temp_'.int(rand(1e19)).'/';
	$export_folder='/tmp/'.$export_subfolder;
	$HM->PegOut("Please hit F5") if -d $export_folder;
	mkdir $export_folder;
	
	my $delete_project=$dbh->prepare (
	"UPDATE ".$HM->{prefix}."projects SET archived=current_date WHERE project_no=? AND user_login=? ") || $HM->die2("SQL error P: ". $DBI::errstr);
	my $delete_analysis=$dbh->prepare(
	"UPDATE ".$HM->{prefix}."analyses SET archived=current_date WHERE project_no=?") || $HM->die2("SQL error A: ".$DBI::errstr);
	my $delete_project_permissions=$dbh->prepare(
	"DELETE FROM ".$HM->{prefix}."projects_permissions WHERE project_no=?") || $HM->die2("SQL error PP:".$DBI::errstr);
	my $q_project=$dbh->prepare ("SELECT * FROM ".$HM->{prefix}."projects WHERE project_no=? AND user_login=?") || $HM->die2("SQL error P: ".$DBI::errstr);
	my $q_analysis=$dbh->prepare ("SELECT * FROM ".$HM->{prefix}."analyses WHERE project_no=? ") || $HM->die2("SQL error P:".$DBI::errstr);

	foreach my $analysis2project (keys %projects2analyses2delete){
		my ($project_id)=split /v/,$analysis2project;
		
		my @tablenames=(( $vcf_project?'vcf':'')."results_".$analysis2project, 
		"samples_".$analysis2project);
		foreach my $tablename (@tablenames) {	
			#next if $tablename=~/vcfresults_209812v/;
			my	$tabletype=($tablename=~/samples/?'analysis_samples':'results');
	
			my $q_sth=$dbh->prepare ("SELECT ".$columns{$tabletype}." FROM ".$HM->{data_prefix}.$tablename) 
				|| $HM->die2("ERROR: Could not query table $tablename". $DBI::errstr);
			my $drop_sth=$dbh->prepare ("DROP TABLE ".$HM->{data_prefix}.$tablename) 
				|| $HM->die2("ERROR: Could not archive table $tablename". $DBI::errstr);
			ExportData($q_sth,$drop_sth,$tablename);
		}
	}

	$delete_project_permissions->execute($project ) || $HM->die2("ERROR: Could not delete project  $project:".$DBI::errstr);
	ExportData($q_analysis,$delete_analysis,'analyses',$project);
		
	ExportData($q_project,$delete_project,'projects',$project, $user_id);
		
	$delete_project->execute($project, $user_id ) || $HM->die2("ERROR: e94 Could not archive project $project:".$DBI::errstr);
		
	my @tablenames=(($vcf_project?'vcf':'')."genotypes_".$project, 
		"samples_".$project);
	foreach my $tablename (@tablenames) {
		my	$tabletype=($tablename=~/samples/?'samples':'genotypes');
	
		my $q_sth=$dbh->prepare ("SELECT ".$columns{$tabletype}." FROM ".$HM->{data_prefix}.$tablename) 
			|| $HM->die2("ERROR: Could not query table $tablename". $DBI::errstr);
		my $drop_sth=$dbh->prepare ("DROP TABLE ".$HM->{data_prefix}.$tablename) 
			|| $HM->die2("ERROR: Could not archive table $tablename". $DBI::errstr);
		ExportData($q_sth,$drop_sth,$tablename);		
	}

	my $targetfile=$project_name.'.zip';
	print "Now zipping your files...<br>\n";
	system ("zip -j $export_folder/$targetfile $export_folder/*");
	$targetfile='/temp/'.$export_subfolder.$targetfile;	
	print qq !<hr> <h1 class="green">DONE.</h1><small>\n!;

	foreach my $datafile (@datafiles) {
		print "deleting $datafile...<br>\n";
		unlink $datafile;
	}
	
	print "</small><br><br>Please download your archived data from <br>";
	print qq !<A HREF="$targetfile">$targetfile</A><br><br>\n!;
	my $deletion_link="/HM/SelectArchive.cgi?species=$FORM{species}";
	$deletion_link.="&unique_id=$unique_id" if $unique_id;
	print qq *<p><A HREF="$deletion_link">Archive further projects.</A></p>
	<p><A HREF="/HomozygosityMapper/$FORM{species}/index.html">Start page.</A></p>*;
	$HM->Commit || $HM->die2("Could not commit: ".$DBI::errstr);	
	print qq *<SCRIPT>stop();</SCRIPT>\n*;
$HM->EndOutput();

sub ExportData {
	$HM->die2('OOO') unless $export_folder;
	my ($sth,$delete_sth,$tablename,@query)=@_;
	print "<small>backing-up ".(@query?'row from':'')." table $tablename\n";
	my $qstring=join("__",@query);
	$sth->execute(@query) || $HM->die2("ERROR: e86 Could not backup $tablename $qstring:".$DBI::errstr);
	my $attribs=$sth->{NAME_lc};
	my $filename=$export_folder.$FORM{species}.$tablename.$qstring.'.txt';
	push @datafiles,$filename;
	open (OUT,'>',$filename) || $HM->die2("Could not write to $filename: ".$!);	

	print OUT join ("\t",@$attribs),"\n";
	#my $r=$sth->fetchall_arrayref;

	#$HM->die2("empty table $tablename") unless @$r;
	print "... writing ... \n";
	my $tuple;
	while ($tuple=$sth->fetchrow_arrayref) {
		print OUT join ("\t",@$tuple),"\n";
	}
	
	close OUT;	
	print "... completed. <br></small>\n";	
	print "<small>deleting ".(@query?'row from':'')." table $tablename ($qstring)<br></small>";	
	$delete_sth->execute(@query ) || $HM->die2("ERROR: e85 Could not archive $tablename $qstring ".$DBI::errstr);
}