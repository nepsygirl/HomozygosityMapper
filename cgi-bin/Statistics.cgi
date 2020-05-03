#!/usr/bin/perl
$|=1;
use strict;
use CGI;
use lib '/www/lib';
use HomozygosityMapper;
my $tmpdir='/tmp/';

my ($DAY, $MONTH, $YEAR) = (localtime)[3,4,5];
my $date=($YEAR+1900).($MONTH+1).$DAY;

my $filename='HM_statistics_'.$date.'.html';
if (-e $tmpdir.$filename){
	my $cgi=new CGI;
	print $cgi->redirect('/temp/'.$filename);
	exit 0;
}

my $HM=new HomozygosityMapper;
$HM->StartOutput(qq !HomozygosityMapper - statistics ($date)!, 
	{	refresh=>['/temp/'.$filename,5],
	}	
); 
print "Don't press reload or F5 - page will be updated automatically...<br>"; 
$HM->StartOutput(qq !HomozygosityMapper - statistics ($date)!, 
	{	
		filename=>$tmpdir.$filename	
	}	
);
print "This page will be updated in 5 seconds. Pressing RELOAD is safe now...<br>"; 
my $dbh=$HM->{dbh};
my $sth=$dbh->prepare ("SELECT COUNT(*) FROM hm.users")  || $HM->PegOut($DBI::errstr);
$sth->execute || $HM->PegOut($DBI::errstr);
my $out= qq !<hr>  <table cellspacing="15">
	<TR>
		<td colspan="3"><b>users</b></td>
		<td width="20%" style="text-align: right">!.commify($sth->fetchrow_arrayref->[0]).
		qq ! </TD></TR><TR>
		<td colspan="4">&nbsp;</td></TR> !;

foreach my $species ('human','cow','dog','horse','mouse','rat','sheep'){
	$HM->SetSpecies($species);
	die ("No dp for $species") unless $HM->{data_prefix};
	$out.=qq ! <tr><td colspan="4"><b>$species</b></td></TR> \n !;
	$sth=$dbh->prepare ("SELECT project_no, marker_count, genotypes_count, deleted, archived, vcf_build FROM $HM->{prefix}projects ORDER BY project_no")  || $HM->PegOut($DBI::errstr);
	$sth->execute ()  || $HM->PegOut($DBI::errstr);
	my $upd=$dbh->prepare ("UPDATE $HM->{prefix}projects SET genotypes_count=? WHERE project_no=?")  || $HM->PegOut($DBI::errstr);
	
	my $results=$sth->fetchall_arrayref  || $HM->PegOut($DBI::errstr);
	my (%markers_count,%markers_in_project)=();
	my $genotypes_count=0;
	my $vcf_genotypes_count=0;
	my $projects_count=0;
	foreach my $project (@$results){
		my ($project_no,$markers_on_chip,$genotypes,$deleted,$archived,$isvcf)=@$project;
	#	print "<tr><td colspan='2'>$project_no,$markers_on_chip,$genotypes,$deleted,$archived,$isvcf</td></tr>\n ";
		unless ($deleted or $archived or length $genotypes) {
			print " \n";
		#	print "reading genotype count from $species / $project->[0]<br>\n";
			my $sql="SELECT COUNT(*) FROM ".$HM->{data_prefix}.($isvcf?'vcf':'')."genotypes_".$project->[0];
			my $sth2=$dbh->prepare ($sql)  || $HM->PegOut(" -> $HM->{data_prefix} <- $DBI::errstr");
		#	print $sql,"<br>\n";
			$sth2->execute ()  || $HM->PegOut(" ->e $HM->{data_prefix} <- $DBI::errstr");
			my $countedgenotypes=$sth2->fetchrow_arrayref->[0];
			unless ($countedgenotypes==$genotypes)		{
				$genotypes=$countedgenotypes;
				$upd->execute ($countedgenotypes,$project_no)  || $HM->PegOut(" ->e $HM->{data_prefix} <- $DBI::errstr");
				$dbh->commit;
	#			print "<tr><td colspan='2'>$project_no: $countedgenotypes</td></tr>\n ";
	#				$dbh->commit();
			}
	
		}
		if ($markers_on_chip > 900000){
			$markers_on_chip='1 1 M';
		}
		elsif ($markers_on_chip > 700000){
			$markers_on_chip='2 800 k';
		}
		elsif ($markers_on_chip > 400000){
			$markers_on_chip='3 500 k';
		}
		elsif ($markers_on_chip > 200000){
			$markers_on_chip='4 250 k';
		}	
		elsif ($markers_on_chip > 40000){
			$markers_on_chip='5 50 k';
		}		
		elsif ($markers_on_chip > 8000){
			$markers_on_chip='6 10 k';
		}	
		elsif ($markers_on_chip > 0){
			$markers_on_chip='7 <10 k';
		}	
		else {
			$markers_on_chip='8 0';
#			print "<pre>$markers_on_chip</pre>";
		}		
		$genotypes_count+=$genotypes;
		$vcf_genotypes_count+=$genotypes if $isvcf;
		$projects_count++;						
		$markers_count{$markers_on_chip}++;
	}
	$dbh->commit();
	$out.= qq !	<tr><td>&nbsp;</td><td colspan="2">projects</td>
		<td style="text-align: right">!.commify($projects_count)."</td></tr>";
	foreach my $count (sort {$a <=> $b} keys %markers_count){
		my $display=$count;
		$display=~s/^\d+//;
		$out.=qq !	<TR><td colspan="2">&nbsp;</td><td>$display markers</td>
		<td style="text-align: right">!.commify($markers_count{$count})."</td></tr>";
	}
	$out.=qq !	<tr><td>&nbsp;</td><td colspan="2">genotypes (approx.)</td>
		<td style="text-align: right">!.commify($genotypes_count)."</td></tr>";
	$out.= qq !	<tr><td>&nbsp;</td><td colspan="2">VCF genotypes (approx.)</td>
		<td style="text-align: right">!.commify($vcf_genotypes_count)."</td></tr>";#  if $vcf_genotypes_count;		
	$sth=$dbh->prepare ("SELECT COUNT(*) FROM ".$HM->{prefix}."analyses")  || $HM->PegOut($DBI::errstr);
	$sth->execute ()  || $HM->PegOut($DBI::errstr);
	$out.= qq !	<tr><td>&nbsp;</td><td colspan="2">analyses</td>
		<td style="text-align: right">!.commify($sth->fetchrow_arrayref->[0])."</td></tr>\n";		
}	
$out.= "</table>";
print $out,qq !<A HREF="http://www.homozygositymapper.org/index.html">back to the homepage</A> !;
$HM->EndOutput();

sub commify {
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text;
}
