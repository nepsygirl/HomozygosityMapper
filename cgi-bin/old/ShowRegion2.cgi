#!/usr/bin/perl
#!perl


use strict;
use CGI;
use GD;

use lib '/www/lib';
use lib 'e:/www/lib';
use HomozygosityMapper_animals;
use Web;
use Data::Dumper;
my $cgi=new CGI;
my $tempdir=($^O=~/win32/i?'t:/www/':'/tmp/');
my $HM=new HomozygosityMapper;
my $www=$HM->{www};
my $user_id=$HM->Authenticate;
#my $user_id='dominik';
my %FORM=$cgi->Vars();
$HM->GetSpecies($FORM{species});
my $snp_prefix=($HM->{species} && $HM->{species} ne 'human'?'#':'rs');
my ($analysis_no)=$cgi->param('analysis_no');
$www->PegOut("No analysis selected!") unless $analysis_no;
$HM->QueryAnalysisName($analysis_no);
my $project_no=$HM->{project_no};
$www->PegOut("No project selected!") unless $project_no;
$www->PegOut("Project unknown!") unless $HM->{project_name};
$www->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$project_no);

my $imgname="hm_gw_".rand(999).'_'.scalar time();
my $img2name=$imgname.'_2.png';
$imgname.='.png';
my %CHR_LENGTH=(
	1  =>249250621,	2  =>243199373,	3  =>198022430,	4  =>191154276,	5  =>180915260,
	6  =>171115067,	7  =>159138663,	8  =>146364022,	9  =>141213431,	10 =>135534747,
	11 =>135006516,	12 =>133851895,	13 =>115169878,	14 =>107349540,	15 =>102531392,
	16 => 90354753,	17 => 81195210,	18 => 78077248,	19 => 59128983,	20 => 63025520,
	21 => 48129895,	22 => 51304566,	);
if ($HM->{species} eq 'dog')	{
	%CHR_LENGTH=(

	1 =>125616256,  2=>88410189,    3=>94715083,    4=>91483860,	 5=>91976430,
	6 =>80642250,   7=>83999179,    8=>77315194,    9=>64418924,   10=>72488556,
	11=>77416458,  12=>75515492,   13=>66182471,	  14=>63938239,   15=>67211953,
	16=>62570175,  17=>67347617,   18=>58872314,   19=>56771304,   20=>61280721,
	21=>54024781,  22=>64401119,   23=>55389570,   24=>50763139,   25=>54563659,
	26=>42029645,  27=>48908698,   28=>44191819,   29=>44831629,   30=>43206070,
	31=>42263495,  32=>41731424,   33=>34424479,   34=>45128234,   35=>29542582,
	36=>33840356,  37=>33915115,   38=>26897727
);
}

my %startpos_chr;
my $startpos=0;

my %colour=();
my $image = new GD::Image(960,420);
my $image2 = new GD::Image(960,40);
AllocateColours($image);
AllocateColours($image2);

my $max=$HM->{max_score};
$www->PegOut("No positive score found!") unless $max;
my $sql="SELECT chromosome, position, score, hom_freq, hom_freq_ref,m.dbsnp_no FROM
$HM->{markers_table} m, $HM->{prefix}results_".$project_no."v".$analysis_no." r WHERE m.dbsnp_no=r.dbsnp_no AND ";
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
	$sql.='chromosome < 23';
}

$sql.=" ORDER BY chromosome, position";
my $query=$HM->{dbh}->prepare($sql) || $www->PegOut ("Did you analyse your project?",{text=>[$sql,$DBI::errstr]});
	$query->execute(@condition_values) ||  $www->PegOut ("Did you analyse your project?",{text=>[$sql,$DBI::errstr]});

my $results=$query->fetchall_arrayref || $www->PegOut ($DBI::errstr);
$www->PegOut("Nothing found.") unless @$results;
my $startpos=0;
my @regions;
my @regionsb;
my $region=0;
my $regionb=0;
my $xfactor=3250000;
my @map;

unless ($FORM{chromosome}){
	foreach my $chr (sort {$a <=> $b} keys %CHR_LENGTH){
		$startpos_chr{$chr}=$startpos;
		$image->line($startpos/$xfactor,400,$startpos/$xfactor,0,$colour{grey});
		$image->string(gdSmallFont,$startpos/$xfactor+1,10,$chr,$colour{green});
		push @map,[$startpos/$xfactor,($startpos+$CHR_LENGTH{$chr})/$xfactor,$chr];
		$startpos+=$CHR_LENGTH{$chr};
	}
}
elsif ($FORM{chromosome}){
	$xfactor=($results->[-1]->[1]-$results->[0]->[1])/960;
	$startpos-=$results->[0]->[1];
}

my $yfactor=350/$max;

#open (OUT,'>',$tempdir.'/hm.log');
#my @tmp;
print "Content-TYpe: text/html\n\n";
foreach my $i (0..$#$results){

	my ($chromosome, $position, $score, $freq_hom, $freq_hom_ref,$marker_no)=@{$results->[$i]};
	#die join (", ",$chromosome, $position, $score, $freq_hom, $freq_hom_ref,$marker_no) if $marker_no==1427282;
#	if ($chromosome==6  && $position>53859977){
#		print OUT join ("\t",$chromosome, $position, $i, $score),"\n";
#	}


	my $lstartpos=$FORM{chromosome}?$startpos:$startpos_chr{$chromosome};
#	$startpos=$FORM{start_pos} unless $startpos;
#	die ("XX $startpos");
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
	#	else {
	#		$image2->line($x,20,$x,20-$freq_hom_ref*20,$colour{grey1});
	#	}
	}
	#die join (", ",$score,.8*$max,@{$results->[$i]})  if $results->[$i]->[-1]==10504098;
#	if ($chromosome==15 or $chromosome==16){
#		print "<pre>COMP $i - $region / $chromosome!=",$results->[$i+1]->[0]	,"</pre>"  ;
#		print "<pre>LR ".join (",",@{$regions[-1]}),'</pre>';
#		print "<pre>X ".join (",",@{$results->[$i]}),'</pre>';
#		print "<pre>X+1 ".join (",",@{$results->[$i+1]}),'</pre>';
#		print "<pre>SR- ".scalar @regions,'</pre>';
#	}

	if ($score>=.8*$max){

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
			elsif ($results->[$i+1]->[2]<.8*$max  or $results->[$i]->[0] != $results->[$i+1]->[0]){
				
				my $last_regionb=pop @regionsb;
				push @regionsb,[$regionb,@$last_regionb,$results->[$i+1]->[1],$results->[$i+1]->[-1]];

			#	die join (", ",@$last_regionb,$results->[$i+1]->[1],$results->[$i+1]->[-1],"---",@{$results->[$i+1]})  if $results->[$i+1]->[-1]==1427282;
			#	push @tmp,[@$last_regionb,$results->[$i+1]->[1],$results->[$i+1]->[-1],"---",@{$results->[$i+1]}]  if $results->[$i+1]->[-1]==1427282;
		#		push @tmp,[@$last_regionb,$results->[$i+1]->[1],$results->[$i+1]->[-1],"---",@{$results->[$i+1]}]  if $results->[$i+1]->[-1]==1427282;
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


if ($FORM{chromosome}){
	$www->StartOutput("Homozygosity on chromosome $FORM{chromosome} in <i>$HM->{project_name}: $HM->{analysis_name}</i>");
}
else {
	$www->StartOutput("Genome-wide homozygosity in <i>$HM->{project_name}: $HM->{analysis_name}</i>");
}

open (IMG, ">",$tempdir.$imgname) || $www->PegOut("Can't write image: $!");
binmode IMG;
print IMG $image->png;
open (IMG, ">",$tempdir.$img2name) || $www->PegOut("Can't write image: $!");
binmode IMG;
print IMG $image2->png;

print qq!<DIV id="image2" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: 70px; visibility: visible; z-index: 21; left: 0px;">\n!;
print qq!<IMG src="/temp/$img2name" width="960" height="40" border=0></DIV>\n!;
print qq!<DIV id="image" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: 100px; visibility: visible; z-index: 20; left: 0px;">\n!;
if ($FORM{chromosome}){
	print qq°
	<script language="JavaScript" type="text/javascript">
	var xfactor=$xfactor;
	var startpos=$startpos;
	</script>
	°;
}
print qq!<IMG src="/temp/$imgname" width="960" height="420" border=0  usemap="#Map">\n!;
print qq!<map name="Map">\n!;
foreach (@map){
	print qq!<area shape="rect" coords="$_->[0],0,$_->[1],420" href="/cgi-bin/HM/ShowRegion.cgi?species=$HM->{species}&analysis_no=$analysis_no&chromosome=$_->[2]">\n!;
}
print "</map>\n";
my $table_start=470;
if ($FORM{chromosome}){
	$table_start+=100;

	print qq°<table width="960"><tr>
	<td width="320" align="left">$results->[0]->[1] bp</td>
	<td width="320" align="center">chromosome $FORM{chromosome}</td>
	<td width="320" align="right">$results->[-1]->[1] bp</td>
	</tr></table>
	<table width="960">
		<tr>
			<td  class="small">
				You can define a region in which you like to zoom in or inspect the genotypes by clicking on the left and right limits of it in the plot. 
				<font color="red">The problem with Microsoft IE has been fixed.</font>
				</td><td  class="small"><A HREF="/HomozygosityMapper/documentation.html#scoreview" TARGET="doc">help</A>
			</td>
		</tr>
	</table>
	</DIV>
	<DIV ID="line" style="position:absolute; width:1px; height: 60px;  top: 525px; background-color: yellow; overflow: visible; visibility: hidden;z-index: 39;	opacity: 0.8;	-moz-opacity:0.8; text-align: center">
	<FORM name="form1" action="/cgi-bin/HM/.cgi" method="POST">
	<INPUT TYPE="hidden" name="start_pos" value="">
	<INPUT TYPE="hidden" name="start_snp" value="">
	<INPUT TYPE="hidden" name="chromosome" value="$FORM{chromosome}">
	<INPUT TYPE="hidden" name="analysis_no" value="$analysis_no">
	<INPUT TYPE="hidden" name="end_pos" value="">
	<INPUT TYPE="hidden" name="end_snp" value="">
	<INPUT TYPE="hidden" name="species" value="$HM->{species}">
	<table>
		<tr>
			<td>
				<A HREF="javascript:ZoomIn()">zoom in</A><BR>
				<A HREF="javascript:Genotypes()">genotypes</A>
			</td>
		</tr>
	</table>
	</FORM>
	<script src="/javascript/HomozygosityMapper_ChooseRegion.js" type="text/javascript"></script></DIV>°;
}
else {
	print qq° 
		<table width="960">
			<tr>
				<td class="small">
					Click on a chromosome to zoom in.
				</td>
				<td class="small">
					<A HREF="/HomozygosityMapper/documentation.html#scoreview" TARGET="doc">help</A>
				</td>
			</tr>
		</table>°;
}

$table_start.='px';
print qq!<DIV id="table" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute;  visibility: visible; z-index: 21; left: 50px; top: $table_start">
$HM->{project_name}: $HM->{analysis_name}<br>
$HM->{analysis_description}
	<TABLE cellspacing="5">\n!;
print "<tr class='bold'><td>",join ("</td><td>",'score','chr','from (bp)','to (bp)','from SNP','to SNP','',''),"</td></tr>\n";

DisplayTableWithLinks('<b>broad</b> - use this when you expect some genetic heterogeneity',[@regionsb]);
DisplayTableWithLinks('<b>narrow</b> - use this when all patients are in the same family',[@regions]);
my $reg=join (",",map {$_->[1],$_->[4],$_->[2]} @regionsb);
print "</TABLE>";
print qq°<span class="red"><b>NEW! </b></span> <A HREF="/cgi-bin/HM/CallGeneDistillerWithAllRegions.cgi?analysis_no=$analysis_no&regions=$reg&species=$HM->species">call GeneDistiller with all regions at once</A>°;
print "</DIV>";
$www->EndOutput();

	
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
		my $link_region="/cgi-bin/HM/ShowRegion.cgi?species=$HM->{species}&chromosome=".$chromosome.'&start_pos='.$start_pos.'&end_pos='.$end_pos.'&analysis_no='.$analysis_no.'&margin=1000000';
		my $link_genotypes="/cgi-bin/HM/DisplayGenotypes.cgi?species=$HM->{species}&chromosome=".$chromosome.'&start_pos='.$start_pos.'&end_pos='.$end_pos.'&start_snp='.$start_snp.'&end_snp='.$end_snp.'&analysis_no='.$analysis_no.'&margin=1000000';
		print qq!<tr><td>$score</td><td>!,join ("</td><td>",$chromosome,$start_pos,$end_pos,$snp_prefix.$start_snp,$snp_prefix.$end_snp),
		qq!</td><td><A HREF="$link_region">region</A></td><td><A HREF="$link_genotypes">genotypes</A></td>
		</tr>\n!;
	}
}