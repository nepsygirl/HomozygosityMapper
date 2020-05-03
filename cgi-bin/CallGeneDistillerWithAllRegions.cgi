#!/usr/bin/perl
use strict;
use CGI;
use lib '/www/lib';
use HomozygosityMapper;

my $cgi=new CGI;
my $HM=new HomozygosityMapper;

my $analysis_no=$cgi->param('analysis_no');
my $user_id=$HM->Authenticate;
my $unique_id=$cgi->param("unique_id") || 0;
my $build=$cgi->param("build") || '';

$HM->QueryAnalysisName($analysis_no);
$HM->PegOut("Project unknown!") unless $HM->{project_name};
$HM->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$HM->{project_no},$unique_id);
my $reg=$cgi->param("regions");
my @regions=split /,/,$reg;
$HM->PegOut("No region specified.") unless (scalar @regions)>=3 ;
$HM->PegOut("Something went wrong with the regions.") if (scalar @regions)%3 ;
my @sql=();
for (my $i=0;$i<=$#regions;$i+=3){ 
	push @sql, "chromosome=$regions[$i] AND start_pos<=$regions[$i+1] AND end_pos>=$regions[$i+2]";
}
my $gp_table='gene_position';
$gp_table.='_36' if $build==36;
my $sql="SELECT gene_no FROM $gp_table  WHERE (".join (") OR (",@sql).')';
my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
$q->execute || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
my $result=$q->fetchall_arrayref;
# $HM->PegOut ("No genes within your region(s).") unless @$result;
my $genes=join (",",map { $_->[0]} @$result);
$HM->PegOut("No genes found!") unless $genes;
my $link='/GD/API.cgi?gene_no='.$genes;
$link.="&analysis_no=$analysis_no" if ($analysis_no && !$unique_id);
$link.='&build='.$build if $build==36;
if (length $link>4000){
	$HM->StartOutput('Query GeneDistiller...');
	print "Your regions contain ",scalar @$result,qq! genes.<br>
	<FORM name="dummy" action="/GD/API.cgi" method="POST">
	<INPUT type="hidden" name="analysis_no" value="$analysis_no">
	<INPUT type="hidden" name="build" value="$build">
	<INPUT type="hidden" name="gene_no" value="$genes">
	<INPUT type="submit"  value="Submit to GeneDistiller">
	<script language="javascript" type="text/javascript">
		document.dummy.submit();
	</script>
	</FORM></BODY></HTML>!;
}
else {
	print $cgi->redirect($link);
}
