#!/usr/bin/perl
#!perl
$|=1;
use strict;
use GD;
use Sort::Naturally;
use lib 'e:/www/lib';
use lib '/www/lib';
my $baseurl='/cgi-bin/HM/DisplayGenotypes.cgi?';
use HomozygosityMapper_animals;
use Web;
my $tmpdir=($^O=~/win32/i?'t:/www/':'/tmp/');
my $imgname="hm_rg_".rand(999).'_'.scalar time().'.png';

my %FORM;
foreach  (@ARGV){
	my ($param,$value)=split /=/;
	$FORM{$param}=$value;
}
my $outputfile=$tmpdir.$FORM{html_output};
my $www=new Web;
$www->StartOutput("Analysis is performed...",
	{	refresh=>[$htmltmpdir.$FORM{html_output},5],
		filename=>$outputfile,
		no_heading=>1,
		'HomozygosityMapperSubtitle'=>'Analysis is performed',
	}	);
print "This page will be updated in 5 seconds. Pressing RELOAD is safe now...<br>";


my $margin=(length $FORM{margin}? $FORM{margin}: 400000);
my %CHR_LENGTH=(
	1  =>249250621,	2  =>243199373,	3  =>198022430,	4  =>191154276,	5  =>180915260,
	6  =>171115067,	7  =>159138663,	8  =>146364022,	9  =>141213431,	10 =>135534747,
	11 =>135006516,	12 =>133851895,	13 =>115169878,	14 =>107349540,	15 =>102531392,
	16 => 90354753,	17 => 81195210,	18 => 78077248,	19 => 59128983,	20 => 63025520,
	21 => 48129895,	22 => 51304566,	23 =>155270560);

my $HM=new HomozygosityMapper;
$HM->GetSpecies($FORM{species});
my $user_id=$HM->Authenticate;
my $www=$HM->www;
my ($analysis_no)=$cgi->param('analysis_no');
$www->PegOut("No analysis selected!") unless $analysis_no;
$HM->QueryAnalysisName($analysis_no);
$www->PegOut("Project unknown!") unless $HM->{project_name};
$www->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$HM->{project_no});
my $snp_prefix=($HM->{species} && $HM->{species} ne 'human'?'#':'rs');
if ($FORM{end_snp} || $FORM{start_snp}){
#	$www->PegOut("Please use either SNP ID <u>or</u> position to indicate the region's start.")
#		if length $FORM{start_pos} && $FORM{start_snp};
#	$www->PegOut("Please use either SNP ID <u>or</u> the position to indicate the region's end.")
#		if length $FORM{end_pos} && $FORM{end_snp};
	my $snp_pos=$HM->{dbh}->prepare ("SELECT position FROM $HM->{markers_table} WHERE dbsnp_no=? AND chromosome=?") || $www->PegOut($DBI::errstr);
	if ($FORM{start_snp} && ! $FORM{start_pos}){
		$FORM{start_snp}=~s/^rs//i;
		$snp_pos->execute($FORM{start_snp},$FORM{chromosome})  || $www->PegOut($DBI::errstr);
		my $pos=$snp_pos->fetchrow_arrayref;
		$www->PegOut("SNP $snp_prefix$FORM{start_snp} was not found") unless ref $pos eq 'ARRAY' and $FORM{start_pos}=$pos->[0];
	}
	if ($FORM{end_snp}&& ! $FORM{end_pos}){
		$FORM{end_snp}=~s/^rs//i;
		$snp_pos->execute($FORM{end_snp},$FORM{chromosome})  || $www->PegOut($DBI::errstr);
		my $pos=$snp_pos->fetchrow_arrayref;
		$www->PegOut("SNP $snp_prefix$FORM{end_snp} was not found") unless ref $pos eq 'ARRAY' and $FORM{end_pos}=$pos->[0];
	}
}

my $analysis_no=$FORM{analysis_no};
my $id=$HM->{project_no}.'v'.$analysis_no;
my $sql="SELECT m.dbsnp_no,position,sample_id,genotype,block_length,score, hom_freq, hom_freq_ref, affected FROM
	$HM->{prefix}samples_".$HM->{project_no}." s, $HM->{prefix}genotypes_".$HM->{project_no}." gt, $HM->{markers_table} m,  $HM->{prefix}samples_".$id." sa, $HM->{prefix}results_".$id." r
	WHERE s.sample_no=gt.sample_no
	AND sa.sample_no=s.sample_no
	AND m.dbsnp_no=r.dbsnp_no
	AND gt.dbsnp_no=m.dbsnp_no
	AND chromosome=? AND position BETWEEN ? AND ?
	ORDER BY position ASC";
my $query_gt=$HM->{dbh}->prepare($sql)|| $www->PegOut({text=>[$sql,$DBI::errstr]});
$query_gt->execute($FORM{chromosome},$FORM{start_pos}-$margin,$FORM{end_pos}+$margin) || $www->PegOut({text=>[($sql,$DBI::errstr)]});
#die(join (" ",$FORM{chromosome},$FORM{start_pos}-$margin,$FORM{end_pos}+$margin));
my $last_marker='';
my $i=-1;
my (@markers,@gt,@block,%samples,@count)=();

#print "Content-Type: text/plain\n\n";
#die (scalar @{$query_gt->fetchall_arrayref});
my $results=$query_gt->fetchall_arrayref;
die scalar @$results;
#if (@$results > 
foreach (@{$query_gt->fetchall_arrayref}){
	my ($db_snp,$position,$sample_id,$genotype,$blocklength,$score, $hom_freq, $hom_freq_ref,$affected)=@$_;
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

my $start=$markers[0]->[1];
my $end=$markers[-1]->[1];
my $basepairs= $end-$start;
my $snps=scalar @markers;
my ($size)=7;
my $img_width=$size*$snps;
my $xmargin=80;
my $ymargin=100;
my $middle=int($i/2);
my @samples;
if ($FORM{sort_by} eq 'blocklength'){
	@samples=((sort {$block[$middle]->{$b} <=> $block[$middle]->{$a}} grep {$samples{$_}} keys %samples),'',(sort {$block[$middle]->{$b} <=> $block[$middle]->{$a}}  grep {!$samples{$_}} keys %samples));
}
else {
	@samples=((nsort grep {$samples{$_}} keys %samples),'',(nsort  grep {!$samples{$_}} keys %samples));
}
my $img_height=$size*scalar @samples;
my $xsize=$xmargin+$img_width+$xmargin;
my $ysize=$ymargin+$img_height+20;
my $image = new GD::Image($xsize,$ysize);
my $baseline=$ymargin+$img_height;
$www->StartOutput(qq°$HM->{project_name} - <i class="blue">$HM->{analysis_name}</i>°);
#print '<pre>'.join ("\n",%ENV).'</pre>';
print qq^
<DIV id="choice" style="border: 1px none rgb(0, 0, 0); overflow: visible; position: absolute; width: 300px; height: 115px; visibility: visible; z-index: 99; left: 100px; top: 21px; display: none;"></DIV>
<script src="/javascript/HomozygosityMapper_DefineIntervalForGeneDistiller.js" type="text/javascript">
</script>
^;
my %colour=();
my $last_sample_index=$#samples;
my $last_marker_index=$snps-1;
AllocateColours($image);
$image->string(gdTinyFont,$xmargin,$baseline+5,$start.' bp',$colour{black});
$image->string(gdTinyFont,$xmargin+$img_width-30,$baseline+5,$end.' bp',$colour{black});
$image->string(gdTinyFont,$xmargin+$img_width/2-15,$baseline+5,'chromosome '.$FORM{chromosome},$colour{black});
my @count2;
for my $i (0..$last_marker_index){
	if ($count[$i]->{3}>$count[$i]->{1}){
		$count2[$i]=3;
	}
	elsif ($count[$i]->{1}>=$count[$i]->{3}){
		$count2[$i]=1;
	}
}

for my $j (0..$last_sample_index){
	my $sample=$samples[$j];
	next unless $sample;
	my $colour='red';
	if (!$samples{$sample}){
		$colour='green';
	}
	$image->string(gdTinyFont,$xmargin-30,$ymargin+$j*$size,$sample,$colour{$colour});
	$image->string(gdTinyFont,$xmargin+$img_width+5,$ymargin+$j*$size,$sample,$colour{$colour});
	for my $i (0..$last_marker_index){
		my $x1=$xmargin+$i*$size;
		my $x2=$x1+$size;
		if ($gt[$i]->{$sample}==2){
			$image->filledRectangle($x1,$ymargin+$j*$size,$x2,$ymargin+$size+$j*$size,$colour{blue});
		}
		elsif ($gt[$i]->{$sample}==1 || $gt[$i]->{$sample}==3){
			$image->filledRectangle($x1,$ymargin+$j*$size,$x2,$ymargin+$size+$j*$size,$colour{GetBlockColour($block[$i]->{$sample})});
			$image->line($x1,$ymargin+$j*$size,$x2,$ymargin+$size+$j*$size,$colour{black}) unless $gt[$i]->{$sample}==$count2[$i];
		}
		else {		
			
			$image->filledRectangle($x1,$ymargin+$j*$size,$x2,$ymargin+$size+$j*$size,$colour{grey});
	#		$image->string(gdTinyFont,$x1,$ymargin+$j*$size,$gt[$i]->{$sample},$colour{black});
		}
	}
}

my %LINK;
my ($start_pos,$end_pos)=();

print qq!<map name="Map">\n!;
for my $i (0..$#markers){
	my $x1=$xmargin+$i*$size;
	my $x2=$x1+$size;
	my $mpos=$xmargin+$i*$size+$size/2;
	print qq!<area shape="rect" coords="$x1,0,$x2,$ysize" href="javascript:SetLimit('$markers[$i]->[0]','$markers[$i]->[1]',$mpos)">\n!;
	
	if ($FORM{gene}){	
		if ( $markers[$i]->[1]<=$FORM{start_pos} && $markers[$i+1]->[1]>=$FORM{start_pos}){
			SetMargin('start',$i,$mpos);
		}
		elsif ( $markers[$i-1]->[1]<=$FORM{end_pos} && $markers[$i]->[1]>=$FORM{end_pos}){
			SetMargin('end',$i,$mpos);
		}
		else {
			$image->stringUp(gdTinyFont,$xmargin+$i*$size,$ymargin-20,$snp_prefix.$markers[$i]->[0],$colour{black});
		}
	}
	else {
		if ( $markers[$i]->[0]==$FORM{start_snp}){
			SetMargin('start',$i,$mpos);
	#		die('start',$i,$mpos);
		}
		elsif ( $markers[$i]->[0]==$FORM{end_snp}){
			SetMargin('end',$i,$mpos);
		}
		else {
			$image->stringUp(gdTinyFont,$xmargin+$i*$size,$ymargin-20,$snp_prefix.$markers[$i]->[0],$colour{black});
		}
	}
}
print qq!</map>\n!;
open (IMG,">", $tmpdir."/$imgname") || die("Can't write image: $!");
binmode IMG;
print IMG $image->png;
my $link=$baseurl.                        'chromosome='.$FORM{chromosome}.'&start_snp='.$FORM{start_snp}.
	'&end_snp='.$FORM{end_snp}.'&start_pos='.$FORM{start_pos}.'&end_pos='.$FORM{end_pos}.'&analysis_no='.$analysis_no.
	'&margin='.($margin*2).'&sort_by='.$FORM{sort_by};
$link.='&gene='.$FORM{gene} if $FORM{gene};
print qq!
<DIV ID="line1" style="border: 1px solid black; position:absolute; width:1 px; top: !.(48+$ymargin).qq!px; height:!.($img_height+4).qq!px;  
overflow: visible; visibility: hidden;z-index: 39;	opacity: 0.5;	-moz-opacity:0.5;">&nbsp;</DIV>
<DIV id="image" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: 50px;
visibility: visible; 
z-index: 20; left: 0px; ">
<IMG src=/temp/$imgname width="$xsize" height="$ysize" usemap="#Map" border="0"></DIV>!;
my $div_y_start=$ysize+60;
print qq!<DIV id="formdiv" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: !.$div_y_start.qq!px; 
visibility: visible; z-index: 20; left: 0px; " >!;

print qq!<FORM name="form1" action="/cgi-bin/GeneDistiller_API.cgi" method="POST">
<INPUT TYPE="hidden" name="x1" value="$LINK{x1}" size="10">
<INPUT TYPE="hidden" name="x2" value="$LINK{x2}" size="10">
<table border="0" cellpadding="10">
<tr><td width="80">&nbsp;</td><td>
<A HREF="$link">zoom<br>out</A></td>
<td>
	<INPUT TYPE="hidden" name="chromosome" value="$FORM{chromosome}">
	<INPUT TYPE="hidden" name="start_snp" value="$FORM{start_snp}">
	<INPUT TYPE="hidden" name="end_snp" value="$FORM{end_snp}">
	<INPUT TYPE="hidden" name="start_pos" value="$FORM{start_pos}">
	<INPUT TYPE="hidden" name="end_pos" value="$FORM{end_pos}">
	<INPUT TYPE="hidden" name="analysis_no" value="$analysis_no">
	<INPUT TYPE="submit" name="submit" value="GeneDistiller">
	</td>
	!;

$div_y_start+=80;
my ($start_snp,$end_snp)=($snp_prefix.$FORM{start_snp},$snp_prefix.$FORM{end_snp});
$link=$baseurl.'species='.$HM->{species}.'&chromosome='.$FORM{chromosome}.'&start_snp='.$FORM{start_snp}.
	'&end_snp='.$FORM{end_snp}.'&start_pos='.$FORM{start_pos}.'&end_pos='.$FORM{end_pos}.'&analysis_no='.$analysis_no.
	'&margin='.$margin;
$link.='&gene='.$FORM{gene} if $FORM{gene};
my $link3=$link;
$link3=~s/DisplayGenotypes/PrintGenotypes/;

my $jslink=$baseurl.'chromosome='.$FORM{chromosome}.'&analysis_no='.$analysis_no.'&margin='.$margin;
print qq!
	<td>The homozygous region to be queried in GeneDistiller is surrounded by a black rectangle.<br>
	To change the region, please click on the limiting markers and on 'GeneDistiller' when the rectangle
	suits your needs.<br> !;
if ($FORM{sort_by} eq 'blocklength'){
	print qq ! Samples are sorted by their block length. <A HREF="$link&sort_by=ID">Sort by ID.</A> !;
}
else {
	print qq ! Samples are sorted by their ID. <A HREF="$link&sort_by=blocklength">Sort by block length.</A> !;
}	
$link.='&sort_by='.$FORM{sort_by};
print qq !	<br><DIV id="linkself"><A HREF="$link">Right-click to bookmark this output.</A><br>
	<A HREF="$link3">Click here for the genotypes table.</A></DIV></td>
	<td><A HREF="/HomozygosityMapper/documentation.html#genotypesview" TARGET="doc">help</A></td></tr>
	</table> 
</FORM>\n</DIV>
<DIV id="info" style="border: 0px none rgb(0, 0, 0); overflow: visible; position: absolute; top: !.$div_y_start.qq!px; 
visibility: visible; z-index: 20; left: 100px; ">$start_snp - $end_snp<br>$FORM{start_pos} - $FORM{end_pos} bp
</DIV>
<script language="JavaScript" type="text/javascript">
if (ns4) l1_style=document.line1;
else if (ns6) l1_style=document.getElementById("line1").style
else if (ie4) l1_style=document.all.line1.style;

var link='$jslink';
var start=$FORM{start_pos};
var end=$FORM{end_pos};

function display_region(v){
	if (document.form1.x2.value==0 || document.form1.x1.value==0) return ;
	l1_style.width=(document.form1.x2.value-document.form1.x1.value)+"px";
	l1_style.display='';
	l1_style.visibility="visible";
	l1_style.left=document.form1.x1.value+"px";
}
display_region();
</script>
!;

#print qq!<small><p>bald:</P><ul><li>Auswahl von Start und Ende mittels JavaScript<li>Zoom und Bildlauf<li>Allelfrequenzen</ul></small>!;

#my @temp_samples=sort keys %temp_samples;
if ($ENV{HTTP_USER_AGENT} = ~/Mozilla\/.*; MSIE/ && $snps>600){
	print qq °<b class="red">You seem to be using Microsoft Internet Explorer. IE is known to have problems displaying 
	large PNG images. So if you don't see any genotypes at all but a black rectangle, this might be an error in your 
	browser. <A HREF="http://getfirefox.com" target="_new">Mozilla Firefox </A> should work fine.</b> °;  #'
}
$www->EndOutput();

sub SetMargin {
	my ($start,$i,$mpos)=@_;
#	die;
	my $x=($start eq 'start'?'x1':'x2');
	$LINK{$x}=$mpos;
	$image->stringUp(gdTinyFont,$xmargin+$i*$size,$ymargin-20,$snp_prefix.$markers[$i]->[0],$colour{red});
	if ($FORM{gene} && $start eq 'start'){
		$image->string(gdTinyFont,$xmargin+($i+1)*$size,$ymargin-15,$FORM{gene},$colour{black});
	}
	if ($markers[$i]->[0]){
		$LINK{$start.'_snp'}=$markers[$i]->[0];
	}
	else {
		$LINK{$start.'_pos'}=$markers[$i]->[1];
	}
}

sub GetBlockColour {
	my $block_length=shift;
	foreach my $class (256,128,64,32,16,4,1){
	return $class if $class<=$block_length;
	}
}

sub AllocateColours {
	my $image=shift;
	$colour{white} = $image->colorAllocate(255,255,255);
	$image->transparent(-1);
	$image->interlaced('true');
	$colour{1}=$image->colorAllocate(255,154,154);
	$colour{4}=$image->colorAllocate(255,151,151);
	$colour{16}=$image->colorAllocate(255,139,139);
	$colour{32}=$image->colorAllocate(255,123,123);
	$colour{64}=$image->colorAllocate(255,91,91);
	$colour{128}=$image->colorAllocate(255,27,27);
	$colour{256}=$image->colorAllocate(255,0,0);
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
}