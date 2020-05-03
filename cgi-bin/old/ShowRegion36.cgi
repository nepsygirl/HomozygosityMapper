#!/usr/bin/perl
#!perl
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

my $unique_id=$FORM{"unique_id"} || 0;
my $HM=new HomozygosityMapper($FORM{species});

my $user_id=$HM->Authenticate;
my $snp_prefix=($HM->{species} && $HM->{species} ne 'human'?'#':'rs');
my ($analysis_no)=$cgi->param('analysis_no');
$HM->{analysis_no}= $analysis_no;
$HM->PegOut("No analysis selected!") unless $analysis_no;
$HM->QueryAnalysisName($analysis_no);
my $project_no=$HM->{project_no};
$HM->PegOut("No project selected!") unless $project_no;
$HM->PegOut("Project unknown!") unless $HM->{project_name};
$HM->PegOut("No access to this project! *") unless $HM->CheckProjectAccess($user_id,$project_no,$unique_id);

if ($HM->{vcf} && $FORM{build}==36) {
	$HM->PegOut("VCF projects cannot be converted to b36.3!");
}

if ($FORM{chromosome}){
	$HM->StartOutput(qq !Homozygosity on chromosome $FORM{chromosome} in $HM->{project_name} - <i class="blue">$HM->{analysis_name}</i>!);
}
else {
	$HM->StartOutput(qq !Genome-wide homozygosity in $HM->{project_name} - <i class="blue">$HM->{analysis_name}</i>!);
}
my $imgname="hm_gw_".rand(999).'_'.scalar time();
my $img2name=$imgname.'_2.png';
$imgname.='.png';

my %startpos_chr;
my $startpos=0;

my %colour=();
my $image = new GD::Image(960,420);
my $image2 = new GD::Image(960,40);
AllocateColours($image);
AllocateColours($image2);

my $max=$HM->{max_score};
$HM->PegOut("No positive score found!") unless $max;

my $threshold=$FORM{threshold}*$max;

print "<small>max homozygosity score: $max<br></small>\n";
#print "<pre> CHECK $user_id,$project_no ".$HM->CheckProjectAccess($user_id,$project_no)."</pre>";

my $sql='';
if ($HM->{vcf}){
	$sql="SELECT chromosome, position, score, hom_freq, hom_freq_ref, position FROM
	$HM->{data_prefix}vcfresults_".$project_no."v".$analysis_no." r WHERE  ";
}
else {
	$HM->{markers_table}='marker_position_36' if $FORM{build}==36;
	$sql="SELECT chromosome, position, score, hom_freq, hom_freq_ref,m.dbsnp_no FROM
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

$sql.=" ORDER BY chromosome, position";
my $query=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Did you analyse your project?",{text=>[$sql,$DBI::errstr]});
$query->execute(@condition_values) ||  $HM->PegOut ("Did you analyse your project?",{text=>[$sql,$DBI::errstr]});
my $results=$query->fetchall_arrayref || $HM->PegOut ($DBI::errstr);
$HM->PegOut("Nothing found.") unless @$results;
print "<small>",scalar @$results," markers<br></small>\n";

my @regions;
my @regionsb;
my $region=0;
my $regionb=0;
my $xfactor=3250000;
my @map;

unless ($FORM{chromosome}){
	foreach my $chr (sort {$a <=> $b} keys %{$HM->{chr_length}}){
		$startpos_chr{$chr}=$startpos;
		$image->line($startpos/$xfactor,400,$startpos/$xfactor,0,$colour{grey});
		$image->string(gdSmallFont,$startpos/$xfactor+1,10,$chr,$colour{green});
		push @map,[$startpos/$xfactor,($startpos+$HM->{chr_length}->{$chr})/$xfactor,$chr];
		$startpos+=$HM->{chr_length}->{$chr};
	}
}
elsif ($FORM{chromosome}){
	$xfactor=($results->[-1]->[1]-$results->[0]->[1])/960;
	$startpos-=$results->[0]->[1];
}

my $yfactor=350/$max;

foreach my $i (0..$#$results){
	my ($chromosome, $position, $score, $freq_hom, $freq_hom_ref,$marker_no)=@{$results->[$i]};
	my $lstartpos=$FORM{chromosome}?$startpos:$startpos_chr{$chromosome};
	my $x=($lstartpos+$results->[$i]->[1])/$xfactor;
	if ($freq_hom_ref){
		my $surplus=$freq_hom-$freq_hom_ref;
		if ($surplus<0){
			$image2->line($x,20,$x,20+$freq_hom_ref*20,$colour{black});
			$image2->line($x,20+$freq_hom_ref*20,$x,20+$freq_hom*20,$colour{blue});
		}
		elsif  ($surplus>0){
			$image2->line($x,20,$x,20-$freq_hom_ref*20,$colour{black});
			$image2->line($x,20-$freq_hom_ref*20,$x,20-$freq_hom*20,$colour{red}) ;
		}
	}
	if ($score>=$threshold){
		$image->line($x,400,$x,400-$results->[$i]->[2]*$yfactor,$colour{red});
		my $iminus= (($chromosome==$results->[$i-1]->[0] and $i> 0 )?-1:0);
		unless ($region){
			unless ($results->[$i+1]->[2]>$score){
				push @regions,[$results->[$i+$iminus]->[0],$results->[$i+$iminus]->[1],$results->[$i+$iminus]->[-1]] ;
				$region=$score if $score>$region;
			}
		}
		unless ($regionb){
			push @regionsb,[$results->[$i+$iminus]->[0],$results->[$i+$iminus]->[1],$results->[$i+$iminus]->[-1]] ;
			$regionb=$score if $score>$regionb;
		}
		if ($region) {
			if ($score>$region){
				pop @regions;
				push @regions,[$results->[$i-1]->[0],$results->[$i-1]->[1],$results->[$i-1]->[-1]] ;
				$region=$score if $score>$region;
			}
			if ($i==$#$results || $chromosome!=$results->[$i+1]->[0]){
				my $last_region=pop @regions;
				push @regions,[$region,@$last_region,$results->[$i]->[1],$results->[$i]->[-1]];
				$region=0;
			}
			elsif ($score>$results->[$i+1]->[2] || $results->[$i]->[0] != $results->[$i+1]->[0]){
				my $last_region=pop @regions;		
				push @regions,[$region,@$last_region,$results->[$i+1]->[1],$results->[$i+1]->[-1]];
				$region=0;
			}
		}
		if ($regionb) {
			$regionb=$score if $score>$regionb;
			if ($i==$#$results  || $chromosome!=$results->[$i+1]->[0]){
				my $last_regionb=pop @regionsb;
				push @regionsb,[$regionb,@$last_regionb,$results->[$i]->[1],$results->[$i]->[-1]];
				$regionb=0;
			}
			elsif ($results->[$i+1]->[2]<$threshold  or $results->[$i]->[0] != $results->[$i+1]->[0]){
				my $last_regionb=pop @regionsb;
				push @regionsb,[$regionb,@$last_regionb,$results->[$i+1]->[1],$results->[$i+1]->[-1]];
				$regionb=0;
			}
		}
	}
	else {
		$image->line($x,400,$x,400-$results->[$i]->[2]*$yfactor,$colour{black});
	}
}

my $last_pos=($results->[-1]->[1]+$startpos)/$xfactor;
foreach my $percentage (.6,.7,.8,.9,"1.0"){
	$image->line(0,400-$percentage*$yfactor*$max,$last_pos,400-$percentage*$yfactor*$max,$colour{grey});
	$image->string(gdSmallFont,$last_pos+5,395-$percentage*$yfactor*$max,$percentage.' x max',$colour{grey6});
}

open (IMG, ">",$tempdir.$imgname) || $HM->PegOut("Can't write image: $!");
binmode IMG;
print IMG $image->png;
open (IMG, ">",$tempdir.$img2name) || $HM->PegOut("Can't write image: $!");
binmode IMG;
print IMG $image2->png;

print qq !<DIV id="image2" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: 70px; visibility: visible; z-index: 21; left: 0px;">\n!;
print qq !<IMG src="/temp/$img2name" width="960" height="40" border=0></DIV>\n!;
print qq !<DIV id="image" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: 100px; visibility: visible; z-index: 20; left: 0px;">\n!;
if ($FORM{chromosome}){
	print qq !
	<script language="JavaScript" type="text/javascript">
	var xfactor=$xfactor;
	var startpos=$startpos;
	</script>
	!;
}
print qq!<IMG src="/temp/$imgname" width="960" height="420" border=0  usemap="#Map">\n!;
print qq!<map name="Map">\n!;
foreach (@map){
	print qq !<area shape="rect" coords="$_->[0],0,$_->[1],420" href="/HM/ShowRegion.cgi?species=$HM->{species}&analysis_no=$analysis_no&chromosome=$_->[2]!.($unique_id?'&unique_id='.$unique_id:'').qq!">\n!;
}
print "</map>\n";
my $table_start=470;
if ($FORM{chromosome}){
	$table_start+=100;
	print qq !<table width="960"><tr>
	<td width="320" align="left">$results->[0]->[1] bp</td>
	<td width="320" align="center">chromosome $FORM{chromosome}</td>
	<td width="320" align="right">$results->[-1]->[1] bp</td>
	</tr></table>
	<table width="960">
		<tr>
			<td  class="small">
				You can define a region in which you like to zoom in or inspect the genotypes by clicking on the left and right limits of it in the plot. 
				</td><td  class="small" style="align: left"><A HREF="/documentation.html#scoreview" TARGET="doc">help</A>
				&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<A HREF="/tutorial.html#chromosomehomozygosity" TARGET="doc">tutorial</A>
			</td>
		</tr>
	</table>
	</DIV>
	<DIV ID="line" style="position:absolute; width:1px; height: 60px;  top: 525px; background-color: yellow; overflow: visible; visibility: hidden;z-index: 39;	opacity: 0.8;	-moz-opacity:0.8; text-align: center">
	<FORM name="form1" action="/HM/.cgi" method="POST">
	<INPUT TYPE="hidden" name="start_pos" value="">
	<INPUT TYPE="hidden" name="start_snp" value="">
	<INPUT TYPE="hidden" name="chromosome" value="$FORM{chromosome}">
	<INPUT TYPE="hidden" name="analysis_no" value="$analysis_no">
	<INPUT TYPE="hidden" name="end_pos" value="">
	<INPUT TYPE="hidden" name="end_snp" value="">
	<INPUT TYPE="hidden" name="species" value="$HM->{species}">
	<INPUT TYPE="hidden" name="unique_id" value="$unique_id">
	<table>
		<tr>
			<td>
				<A HREF="javascript:ZoomIn()">zoom in</A><BR>
				<A HREF="javascript:Genotypes()">genotypes</A>
			</td>
		</tr>
	</table>
	</FORM>
	<script src="/javascript/HomozygosityMapper_ChooseRegion.js" type="text/javascript"></script></DIV>!;
}
else {
	print qq ! 
		<table width="960">
			<tr>
				<td class="small">
					Click on a chromosome to zoom in.
				</td>
				<td class="small" style="align: left">
					<A HREF="/HomozygosityMapper/documentation.html#scoreview" TARGET="doc">help</A>				&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<A HREF="/tutorial.html#genomewidehomozygosity" TARGET="doc">tutorial</A>
				</td>
			</tr>
		</table>		
		!;
}

$table_start.='px';
print qq !<DIV id="table" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute;  visibility: visible; z-index: 21; left: 50px; top: $table_start">
	<TABLE cellspacing="5">\n!;
my $build='build '.$FORM{build};
print "<tr class='bold'><td>",join ("</td><td>",'score','chr','from (bp)','to (bp)','from SNP','to SNP',$build,''),"</td></tr>\n";

DisplayTableWithLinks('<b>broad</b> - use this when you expect some genetic heterogeneity',[@regionsb]);
DisplayTableWithLinks('<b>narrow</b> - use this when all patients are in the same family',[@regions]);

print "</TABLE><br>";
my $regb=join (",",map {$_->[1],$_->[4],$_->[2]} @regionsb);
my $reg=join (",",map {$_->[1],$_->[4],$_->[2]} @regions);

my $regb_bed=join (",",map {"$_->[1]:$_->[2]-$_->[4]"}@regionsb);
my $reg_bed=join (",",map {"$_->[1]:$_->[2]-$_->[4]"} @regions);

print qq !<FORM action="/HM/ShowRegion36.cgi" method="post" name="setthreshold" >\n!;
foreach my $key (keys %FORM){
	unless ($key eq 'threshold'){
		print qq!<input type="hidden" name="$key" value="$FORM{$key}">!;
	}
}
print qq !<TABLE cellpadding="5" style="border: 1px solid #0000FF;" width="100%">
		<TR><TD>
		<i class="bold" style="border-bottom: solid 1px #999999; font-size:12pt; color:#555555">
		change threshold</i>
		</td><td>
		<SELECT name="threshold">\n!;
foreach my $thresh ('0.9','0.8','0.7','0.6','0.5'){
	my $selected=($thresh eq $FORM{threshold}?'selected':'');
	print qq !<option value="$thresh" $selected>$thresh x max</option>\n!;
}
print qq !</SELECT><INPUT TYPE="submit" value="change"></tr></table><br>\n!;


if (@regions) {
	if (! $HM->{species} || $HM->{species} eq 'human') {
	print qq ~
		<FORM action="/HM/CallGeneDistillerWithAllRegions.cgi" method="post" name="GeneDistiller" target="_blank">
		<TABLE cellpadding="5" style="border: 1px solid #0000FF;" width="100%">
		<TR><TD><i class="bold" style="border-bottom: solid 1px #999999; font-size: 12pt; color:#555555">call GeneDistiller $build</i></td>
		<td>
		<input type="hidden" name="analysis_no" value="$analysis_no">
		<input type="hidden" name="species" value="$HM->{species}">
		<input type="hidden" name="unique_id" value="$unique_id">
		<input type="hidden" name="build" value="$FORM{build}">
		 with all <select name="regions">
		<option value="$reg">narrow</option>
		<option value="$regb" selected>broad</option>
		</select>
		regions at once </td><td style="vertical-align:middle; text-align: right">
		<input type="submit" name="submit" value="GeneDistiller"></td></tr></table>
		</FORM><br> ~;
	} # "
	print qq ~
	<FORM action="/HM/CreateAlohomoraFiles.cgi" method="post" name="alohomora" target="_blank">
	<input type="hidden" name="analysis_no" value="$analysis_no">
	<input type="hidden" name="species" value="$HM->{species}">
	<input type="hidden" name="unique_id" value="$unique_id">
	
	<TABLE cellpadding="5" style="border: 1px solid #0000FF;" width="100%">
		<TR><TD colspan="2">
		<i class="bold" style="border-bottom: solid 1px #999999; font-size:12pt; color:#555555">
		create files for <A href="http://gmc.mdc-berlin.de/alohomora/" target="_blank" style="text-decoration: none">Alohomora</A></i>
		</td></tr><tr><td>
	flanking region <input type="text" name="flanking" value="10000" size="7">[bp]
	<select name="frequencies">
		<option value="from all">allele frequencies from all samples</option>
		<option value="from controls">allele frequencies from controls</option>
		<option value="">allele frequencies equally distributed</option>
	</select> 
	<select name="regions">
		<option value="$reg">narrow regions</option>
		<option value="$regb" selected>broad regions</option>
	</select></td><td style="vertical-align:middle; text-align: right">
	<input type="submit" name="submit" value="create files"></td></tr></table>
	</form><br>
		<FORM action="/GD/CreateBEDfile.cgi" method="post" name="BEDfile" target="_blank">
		<input type="hidden" name="many_regions" value="1">
		<input type="hidden" name="type" value="region">
		<input type="hidden" name="build" value="$FORM{build}">
		<TABLE cellpadding="5" style="border: 1px solid #0000FF;" width="100%">
		<tr><td colspan="4">
		<i class="bold"  style="border-bottom: solid 1px #999999; font-size: 12pt; color:#555555">create a BED file $build</i></td></tr>
		<TR><TD>

		<INPUT TYPE="radio" name="target" value="regions" >complete homozygous regions shown here<br></td>
		<td>&nbsp;</td><td rowspan="2" style="vertical-align:middle"><select name="region">
		<option value="$reg_bed">narrow regions</option>
		<option value="$regb_bed" selected>broad regions</option>
		</select></td>
		<td rowspan="2" style="vertical-align:middle; text-align: right" >
		<INPUT TYPE="submit" name="submit" value="submit">
		</td></tr><tr>
		<td><INPUT TYPE="radio" name="target" value="genes">complete genes within these
		<INPUT TYPE="radio" name="target" value="exons" checked>only exons		
		</td><td>
		flanked by <INPUT type="text" name="flanking_intron" value="200" size="4"> bases on each side.
		</td></tr></table></FORM><br> ~;
		
	}
	
	print qq !<TABLE cellpadding="2" style="border: 1px solid #0000FF;" width="100%">
	<tr><td colspan="3"><i class="bold" style="border-bottom: solid 1px #999999; font-size:12pt; color:#555555">analysis settings</i></td></tr>!;
	foreach my $attribute (qw /project_name analysis_name analysis_description max_block_length max_score access_restricted allele_frequencies user_login vcf_build homogeneity_required lower_limit date exclusion_length /) {
		my $extra=($attribute~~[qw /project_name analysis_name/]?qq !<A HREF="/HM/SelectChange.cgi?species=$HM->{species}&analysis_no=$analysis_no&project_no=$project_no" TARGET="_blank"  style="font-size: 9pt">change name</A>!:'');	
		print qq !<tr><td style="font-size: 9pt">$attribute</td><td style="font-size: 9pt">$HM->{$attribute}</td><td>$extra</td></tr>! if length $HM->{$attribute};
	}
	$HM->GetState();
	foreach (qw/cases controls/) {
		print qq !<tr><td style="font-size: 9pt">$_</td><td colspan="2" style="font-size: 9pt">!,(ref $HM->{$_} eq 'ARRAY'?join (",",@{$HM->{$_}}):'none'),"</td></tr>\n";
	}
	print "</table><br>";
print "</DIV></DIV>";
$HM->EndOutput();

	
sub AllocateColours {
	my $image=shift;
	$colour{white} = $image->colorAllocate(255,255,255);
	$image->transparent(-1);
	$image->interlaced('true');
	$colour{black} = $image->colorAllocate(0,0,0); 
	$colour{blue} = $image->colorAllocate(0,0,255);
	$colour{grey} = $image->colorAllocate(200,200,200);
	$colour{red} = $image->colorAllocate(255,0,0);      
	$colour{red2} = $image->colorAllocate(255,100,100); 
	$colour{red3} = $image->colorAllocate(255,150,150); 
	$colour{green} = $image->colorAllocate(0,215,0);
	$colour{lightgreen} = $image->colorAllocate(122,255,122);
	$colour{lightred} = $image->colorAllocate(255,150,150); 
	$colour{paleblue} = $image->colorAllocate(200,200,255);
	$colour{10} = $image->colorAllocate(200,200,0);
	$colour{1000} = $colour{lightred}; 
	$colour{100} = $colour{paleblue} ;
	$colour{grey1}=$image->colorAllocate(230,230,230);
	$colour{grey2}=$image->colorAllocate(200,200,200);
	$colour{grey3}=$image->colorAllocate(170,170,170);
	$colour{grey4}=$image->colorAllocate(140,140,140);
	$colour{grey5}=$image->colorAllocate(110,110,110);
	$colour{grey6}=$image->colorAllocate(80,80,80);
	$colour{-5} = $image->colorAllocate(0,0,255);
	$colour{-4} = $image->colorAllocate(0,51,255);
	$colour{-3} = $image->colorAllocate(0,102,255);
	$colour{-2} = $image->colorAllocate(0,153,255);
	$colour{-1} = $image->colorAllocate(0,255,255);
	$colour{0} = $image->colorAllocate(0,255,0);
	$colour{1} = $image->colorAllocate(153,255,0);
	$colour{2} = $image->colorAllocate(204,204,0);
	$colour{3} = $image->colorAllocate(255,153,0);
	$colour{4} = $image->colorAllocate(255,51,0);
	$colour{5} = $image->colorAllocate(255,0,0);
}

sub DisplayTableWithLinks {
	my ($title,$aref)=@_;
	print qq!<tr><td colspan="8" style="background-color: #CCCCCC;	padding-left: 14px;	-moz-border-radius: 15px; border-radius: 15px;"><i>$title</i></td></tr>!;
	foreach (sort {$b->[0] <=> $a->[0]}@$aref){
		my ($score,$chromosome,$start_pos,$start_snp,$end_pos,$end_snp)=@$_;
		my $link_region="/HM/ShowRegion.cgi?species=$HM->{species}&chromosome=".$chromosome.'&start_pos='.$start_pos.'&end_pos='.$end_pos.'&analysis_no='.$analysis_no.'&margin=1000000';
		$link_region='&build='.$FORM{build} if $FORM{build}==36;
		my $link_genotypes="/HM/DisplayGenotypes.cgi?species=$HM->{species}&chromosome=".$chromosome.'&start_pos='.$start_pos.'&end_pos='.$end_pos.'&start_snp='.$start_snp.'&end_snp='.$end_snp.'&analysis_no='.$analysis_no.'&margin=1000000';
		$link_genotypes='&build='.$FORM{build} if $FORM{build}==36;
		if ($unique_id){
			$link_region.="&unique_id=".$unique_id;
			$link_genotypes.="&unique_id=".$unique_id;
		}
		print qq !<tr><td>$score</td><td>!,join ("</td><td>",$chromosome,$start_pos,$end_pos,$snp_prefix.$start_snp,$snp_prefix.$end_snp),
		qq !</td><td><A HREF="$link_region">region</A></td><td><A HREF="$link_genotypes">genotypes</A></td>
		</tr>\n!;
	}
}

__END__
