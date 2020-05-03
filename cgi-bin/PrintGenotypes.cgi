#!/usr/bin/perl
#!perl

use strict;
use CGI;
use GD;
use Sort::Naturally;
use lib '/www/lib';

use HomozygosityMapper;
my $tmpdir=($^O=~/win32/i?'t:/www/':'/tmp/');
my $cgi=new CGI;

my %FORM=$cgi->Vars();
my $show_table=$FORM{show_genotypes_table};
#die (join ("\n",%FORM));
$FORM{margin}=500000 if $FORM{margin}>500000;
my $margin=(length $FORM{margin}? $FORM{margin}: 400000);

my $HM=new HomozygosityMapper($FORM{species});
my $user_id=$HM->Authenticate;

my $snp_prefix=($HM->{species} && $HM->{species} ne 'human'?'#':'rs');
my ($analysis_no)=$cgi->param('analysis_no');
$HM->PegOut("No analysis selected!") unless $analysis_no;
$HM->QueryAnalysisName($analysis_no);
$HM->PegOut("Project unknown!") unless $HM->{project_name};
$HM->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$HM->{project_no},$FORM{'unique_id'});
if ($FORM{end_snp} || $FORM{start_snp}){
	my $snp_pos=$HM->{dbh}->prepare ("SELECT position FROM markers WHERE dbsnp_no=? AND chromosome=?") || $HM->PegOut($DBI::errstr);
	if ($FORM{start_snp} && ! $FORM{start_pos}){
		$FORM{start_snp}=~s/^rs//i;
		$snp_pos->execute($FORM{start_snp},$FORM{chromosome})  || $HM->PegOut($DBI::errstr);
		my $pos=$snp_pos->fetchrow_arrayref;
		$HM->PegOut("SNP rs$FORM{start_snp} was not found") unless ref $pos eq 'ARRAY' and $FORM{start_pos}=$pos->[0];
	}
	if ($FORM{end_snp}&& ! $FORM{end_pos}){
		$FORM{end_snp}=~s/^rs//i;
		$snp_pos->execute($FORM{end_snp},$FORM{chromosome})  || $HM->PegOut($DBI::errstr);
		my $pos=$snp_pos->fetchrow_arrayref;
		$HM->PegOut("SNP rs$FORM{end_snp} was not found") unless ref $pos eq 'ARRAY' and $FORM{end_pos}=$pos->[0];
	}
}

my $id=$HM->{project_no}.'v'.$analysis_no;
my $sql='';
if ($HM->{vcf}){
	$sql="SELECT r.position,r.position,sample_id,genotype,block_length,score, hom_freq, hom_freq_ref, affected
	FROM ".$HM->{data_prefix}."samples_".$HM->{project_no}." s, ".$HM->{data_prefix}."vcfgenotypes_".$HM->{project_no}." gt,
	".$HM->{data_prefix}."samples_".$id." sa, ".$HM->{data_prefix}."vcfresults_".$id." r
	WHERE s.sample_no=gt.sample_no
	AND sa.sample_no=s.sample_no
	AND gt.position=r.position
	AND r.chromosome=?
	AND r.position BETWEEN ? AND ?
	ORDER BY position ASC";
}
else {
	$sql="SELECT m.dbsnp_no,position,sample_id,genotype,block_length,score, hom_freq, hom_freq_ref, affected
	FROM ".$HM->{data_prefix}."samples_".$HM->{project_no}." s, ".$HM->{data_prefix}."genotypes_".$HM->{project_no}." gt,
	$HM->{markers_table} m,  ".$HM->{data_prefix}."samples_".$id." sa, ".$HM->{data_prefix}."results_".$id." r
	WHERE s.sample_no=gt.sample_no
	AND sa.sample_no=s.sample_no
	AND m.dbsnp_no=r.dbsnp_no
	AND gt.dbsnp_no=m.dbsnp_no
	AND chromosome=? AND position BETWEEN ? AND ?
	ORDER BY position ASC";
}
my $query_gt=$HM->{dbh}->prepare($sql)|| $HM->PegOut({text=>[$sql,$DBI::errstr]});
$query_gt->execute($FORM{chromosome},$FORM{start_pos}-$margin,$FORM{end_pos}+$margin) || $HM->PegOut({text=>[($sql,$DBI::errstr)]});
#die(join (" ",$FORM{chromosome},$FORM{start_pos}-$margin,$FORM{end_pos}+$margin));
my $last_marker='';
my $i=-1;
my (@markers,@gt,@block,%samples,@count)=();
my %temp_table;
#print "Content-Type: text/plain\n\n";
#die (scalar @{$query_gt->fetchall_arrayref});
foreach (@{$query_gt->fetchall_arrayref}){
	my ($db_snp,$position,$sample_id,$genotype,$blocklength,$score, $hom_freq, $hom_freq_ref,$affected)=@$_;
	$temp_table{$db_snp}->{$sample_id}=[$genotype,$blocklength];
	unless ($db_snp == $last_marker){
		$i++;
		push @markers,[$db_snp,$position,$score, $hom_freq, $hom_freq_ref];
		$last_marker=$db_snp;
	}
	$gt[$i]->{$sample_id}=$genotype;
	$samples{$sample_id}=$affected unless defined $samples{$sample_id};
	if ($affected){
		$count[$i]->{$genotype}++ if $genotype==1 || $genotype==3;
	}
	$block[$i]->{$sample_id}=$blocklength;
}

my $snps=scalar @markers;
my $last_marker_index=$snps-1;

my @samples=((nsort grep {$samples{$_}} keys %samples),'',(nsort  grep {!$samples{$_}} keys %samples));

$HM->StartOutput(qq !$HM->{project_name} - <i class="blue">$HM->{analysis_name}</i>!);




print "<br><table border=1>";
print "<tr><td>".($snp_prefix eq 'rs'?'dbsnp':'#')."</td><td>pos on chr $FORM{chromosome}</td><td>score</td>";
my $colour='red';
foreach my $sample (@samples){
	unless ($sample){
		$colour='green';
	}
	else {
		print qq!<td class="$colour">$sample</td>!;
	}
}
@samples=grep {$_} @samples;
print "</tr>";
foreach my $markerref (@markers){

	my $marker=$markerref->[0];
	#die ($marker);
	my $colour_m=($marker == $FORM{start_snp} || $marker == $FORM{end_snp}?qq! class="red bold"!:'');
	print "<tr><td $colour_m>$snp_prefix$marker</td><td>$markerref->[1]</td><td>$markerref->[2]</td>";
	foreach my $sample (@samples){
		unless (ref ($temp_table{$marker}->{$sample}) eq 'ARRAY'){
			print qq!<td style="red">?</td>!;
		}
		else {
		my ($gt, $block_length)=@{$temp_table{$marker}->{$sample}};
		my $colour;
		if ($gt eq '0'){
			$gt='-';
		}
		elsif ($gt ==1){
			$colour='red';
			$gt='AA';
		}
		elsif ($gt ==2){
			$colour='blue';
			$gt='AB';
		}
		elsif ($gt ==3){
			$colour='orange';
			$gt='BB';
		}
		print "<td bgcolor='$colour'>$gt ($block_length)</td>";
	}
	}
	print "</tr>";
}
print "</table>";



$HM->EndOutput();