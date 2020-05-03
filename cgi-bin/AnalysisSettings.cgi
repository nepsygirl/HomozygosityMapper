#!/usr/bin/perl
#!perl
use strict;
use CGI;
use HTML::Template;
use lib '/www/lib/';
use HomozygosityMapper;
my $file='/www/HomozygosityMapper/html/AnalysisSettings_template.html';
my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $user_id=$HM->Authenticate;
my $unique_id=$FORM{"unique_id"} || 0;
my $projectsref=$HM->AllProjects($user_id,undef,$unique_id);
my $analysesref=($FORM{project_no} || $FORM{reanalysis_no})?$HM->AllAnalyses($user_id,undef,$unique_id):[];
PegOut("No projects accessible for you!") unless ref $projectsref eq 'ARRAY' and @$projectsref>0;


	#die ($FORM{reanalysis_no}) if $FORM{reanalysis_no};
my $out;
my $drop_down_content='';
my $analysis_selected=0;
foreach (@$analysesref){
	if ($FORM{project_no}){
		next unless $FORM{project_no}==$_->[0];
	}
	my $class=($_->[8] eq $user_id ? qq!class="blue"! : qq!class="$_->[8] "!);
	my $selected='';
#	$out.="-ANO $_->[1]== REANO $FORM{reanalysis_no}-".join (", ",,@$_)."<br>";
	if ($_->[1]==$FORM{reanalysis_no}){
		$analysis_selected=1;
		$selected='selected';
		@FORM {qw /project_no analysis_name analysis_description	allele_frequencies limit_block_length homogeneity_required lower_limit exclusion_length/ }
			= @{$_}[0,3,4,6,7,11,12,14]; # /
		my $q=$HM->{dbh}->prepare ("SELECT sample_id, affected FROM
		$HM->{data_prefix}samples_".$FORM{project_no}." s,  $HM->{data_prefix}samples_".$FORM{project_no}.'v'.$FORM{reanalysis_no}." sa
		WHERE sa.sample_no=s.sample_no ") || die ("1",$DBI::errstr);
		$q->execute()  || die ("2",$DBI::errstr);
		my $results=$q->fetchall_arrayref()  || die ("3",$DBI::errstr);
		my (@cases,@controls)=();
		foreach my $r (@$results){
			if ($r->[1]){
				push @cases,$r->[0];
			}
			else {
				push @controls,$r->[0];
			}
		}
		$FORM{analysis_name}.="_copy";
		$FORM{cases_ids}=join (", ",@cases);
		$FORM{controls_ids}=join (", ",@controls);
	#	die (join (",",%FORM));
	}
	else {
		$selected='';
	}
	$drop_down_content.=qq!<OPTION value="$_->[1]" $selected $class>$_->[2]: $_->[3]</OPTION>\n!;
}
#die ($out) if $FORM{reanalysis_no};
my $template = HTML::Template->new(filename => $file);
$template->param(reanalysis => $drop_down_content);

$drop_down_content='';


foreach (@$projectsref){
	my $class=($_->[3] eq $user_id ? qq!class="blue"! : qq!class="$_->[3] "!);
	if ( $FORM{project_no} == $_->[0]) {
		$drop_down_content.=qq!<OPTION value="$_->[0]" selected $class>$_->[1]</OPTION>\n!;
		$FORM{exclusion_length_recommended}=$HM->DefineExclusionLength($_->[5]);
	}
	else {
		$drop_down_content.=qq!<OPTION value="$_->[0]" $class>$_->[1]</OPTION>\n!;
	}
}


$template->param(projects => $drop_down_content);
# unless ($FORM{'exclusion_length'}){
#	$FORM{'exclusion_length'}=20 unless $FORM{'homogeneity_required'} and $analysis_selected;
#}
foreach my $item (qw /cases_ids controls_ids analysis_name analysis_description
		 limit_block_length lower_limit exclusion_length exclusion_length_recommended/) {   # /
	$template->param($item => $FORM{$item}); #; if $FORM{$item};	
	$out.="$item => $FORM{$item}<br>\n" ;	
}
foreach my $item (qw /homogeneity_required/){
	if ($FORM{$item}){
		$template->param($item => 'checked') ;	
	}
	else {
		$template->param($item => '') ;	
	}
}

my @freqs=(
	['controls','from controls'],
	['hapmap_1','HapMap: CEPH (European origin)'],
	['hapmap_2','HapMap: Yoruba)'],
	['hapmap_3','HapMap: HapMap: Han Chinese'],
	['hapmap_4','HapMap: HapMap: Japanese']);
$drop_down_content='';
foreach (@freqs){
	my $selected=($FORM{allele_frequencies} eq $_->[0]?'selected':'');
	$drop_down_content.=qq!<OPTION value="$_->[0]" $selected>$_->[1]</OPTION>\n!;
}
$template->param(allele_freqs => $drop_down_content);
$template->param(species => $FORM{species}) if $FORM{species};
$template->param(species_latin_name => $HM->{species_latin_name});
$template->param(icon => $HM->{icon});
$template->param(icon_desc => $HM->{icon_desc});
$template->param(unique_id => $unique_id) if $unique_id;

# send the obligatory Content-Type and print the template output
print "Content-Type: text/html\n\n", $template->output;