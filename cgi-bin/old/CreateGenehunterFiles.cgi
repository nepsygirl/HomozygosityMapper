#!/usr/bin/perl
$|=1;

#http://www.homozygositymapper.org/HM/CreateGenehunterFiles.cgi?analysis_no=85&regions=7,36547689,29786382&species=HomozygosityMapper=HASH(0xe3f300)-%3Especies
#http://www.homozygositymapper.org/HM/CreateGenehunterFiles.cgi?analysis_no=85&regions=7,36547689,29786382&species=human


use strict;
use CGI;
use lib '/www/lib';
use HomozygosityMapper;

my $cgi=new CGI;
my $HM=new HomozygosityMapper;
my $flanking = $cgi->param('flanking') || 0;
my $freqs = $cgi->param('frequencies') || 'from all';
#my $fh = $cgi->upload('pedfile');
#unless ($fh){
	#$HM->PegOut("File could not be read.");
#};
#ReadPedfile();
my $analysis_no=$cgi->param('analysis_no');
my $user_id=$HM->Authenticate;
my $unique_id=$cgi->param("unique_id") || 0;

$HM->QueryAnalysisName($analysis_no);
my $id=$HM->{project_no}.'v'.$analysis_no;
$HM->PegOut("Project unknown!") unless $HM->{project_name};
$HM->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$HM->{project_no},$unique_id);
my $zipfile='Alohomora_'.$HM->{project_name}.$HM->{analysis_name}."_".int(rand(1e8));
$zipfile=~s/\W+/_/g;

my @sql=();

$HM->StartOutput ("[HomozygosityMapper] Linkage files");
print "Creating linkage files...<br>This might take some minutes - do <b>NOT</b> press RELOAD<br>\n";

#my $markers=CreateMapFile($cgi->param("regions"));
#CreateGenotypesFile($markers);



#my $markers=Query($cgi->param("regions"),$id,$freqs);
Query($cgi->param("regions"),$id,$freqs,$zipfile);
#ReadHapMapFrequencies($markers,$freqs) if $freqs=~/hapmap/i;
Zip($zipfile);

exit 0;

sub Zip {
	my $zipfile=shift;
	print "Now zipping Alohomora files...<br>\n";
	my $command="zip ".$zipfile.".zip ".$zipfile.".map ".$zipfile.".freq ".$zipfile.".genotypes ";
	print $command,"<br>\n";
	chdir "/tmp/";
	system ($command);
	
	print qq !<h2><A HREF="/temp/!.$zipfile.qq!.zip">download files for Alohomora</A></h2></BODY></HTML>\n!;
}

sub Query {
	my ($reg,$id,$freqs,$zipfile)=@_;
	my @regions=split /,/,$reg;
	
	my %translation=(0 => 'NoCall', 1 => 'AA', 2=>'AB', 3=> 'BB');
#	print "I $id<br>";
	$HM->PegOut("No region specified.") unless (scalar @regions)>=3 ;
	$HM->PegOut("Something went wrong with the regions.") if (scalar @regions)%3 ;
	my $sql="SELECT s.sample_no, sample_id, affected FROM
		$HM->{data_prefix}samples_".$id." sa,
		$HM->{data_prefix}samples_".$HM->{project_no}.' s WHERE s.sample_no=sa.sample_no';
	my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
	$q->execute || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
	my $results=$q->fetchall_arrayref;	
	my %samples=();
	my %controls=();
	foreach (@$results){
		$samples{$_->[0]}=$_->[1];
		$controls{$_->[0]}=1 unless $_->[2];
	}
	my @samples=sort keys %samples;
#	print join (", ",@samples,@samples{@samples}),"<br>";
#	print join (", ",%samples),"<br>";
		
	
	my @sql;
	
	
	for (my $i=0;$i<=$#regions;$i+=3){ 
		push @sql, "chromosome=$regions[$i] AND position BETWEEN ".($regions[$i+2]-$flanking)." AND ".($regions[$i+1]-$flanking);
	}
	$sql="SELECT m.dbsnp_no,chromosome,position,sa.sample_no,genotype";
	if ($freqs eq 'from controls' ){
		$sql.= ', affected ';
	}
	$sql.=" FROM
		$HM->{data_prefix}genotypes_".$HM->{project_no}." gt, 
		$HM->{markers_table} m,  $HM->{data_prefix}samples_".$id." sa
		WHERE sa.sample_no=gt.sample_no
		AND gt.dbsnp_no=m.dbsnp_no
		AND (".join (") OR (",@sql).') 
		ORDER BY chromosome ASC, position ASC, m.dbsnp_no, sample_no';
	$q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
	$q->execute || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
	$results=$q->fetchall_arrayref;
	$HM->PegOut("No suitable markers/genotypes found!") unless @$results;
	open (OUT,'>','/tmp/'.$zipfile.'.map') || die ($!);
	print OUT join ("\t",'#Chr','Probe Set ID','map','physical position'),"\n";
	open (OUT2,'>','/tmp/'.$zipfile.'.genotypes') || die ($!);
	print OUT2 join ("\t",'#ID',@samples{@samples}),"\n";
	open (OUT3,'>','/tmp/'.$zipfile.'.freq') || die ($!);
	print OUT3 join ("\t",'#ID','freqA'),"\n";
	
	my %markers=();
	my @markers=();
	my %gt=();
	my ($count_a,$count_b)=(0,0);
	for my $i (0..$#$results){
		unless ($i%5000){
			print "$i / ".(scalar @$results)."<br>\n";
		}
		my ($snp,$chr,$pos)=@{$results->[$i]}[0..2];
		#unless ($markers[-1] eq '$snp'){
		unless ($markers{$snp} ){
			print OUT join ("\t",sprintf ("%02d",$chr),'rs'.$snp,$pos/1e6,$pos),"\n";
			if (%gt){
				print OUT2 join ("\t",'rs'.$results->[$i-1]->[0],@gt{@samples}),"\n" ;
				PrintFreq($snp,$count_a,$count_b);
			}
			($count_a,$count_b)=(0,0);
			$markers{$snp}=1;
		#	push @markers,$snp;
			%gt=();
		}
		my ($sample,$gt)=@{$results->[$i]}[3,4];
		$gt{$sample}=$translation{$gt};
		
		if ($freqs eq 'from all' or ($freqs eq 'from controls' and $controls{$sample}) ){
			if ($gt == 1){
				$count_a+=2;
			}
			if ($gt == 2){
				$count_a+=1;
				$count_b+=1;
			}
			if ($gt == 3){
				$count_b+=2;
			}			
		}
	}
	print OUT2 join ("\t",'rs'.$results->[-1]->[0],@gt{@samples}),"\n";
	PrintFreq($results->[-1]->[0],$count_a,$count_b);
	close OUT;
	close OUT2;
	close OUT3;
	print "Files created!<br>\n";
	#return [@markers];
}

sub PrintFreq {
	my ($snp,$count_a,$count_b)=@_;
	unless ($count_a || $count_b){
		($count_a,$count_b)=(.5,.5);
	}
	my $freq_a=sprintf ("%1.2f",$count_a/($count_a+$count_b));
	if ($freq_a<0.01){
		$freq_a=0.01 ;
	}
	elsif ($freq_a>0.99){
		$freq_a=0.99 ;
	}
	print OUT3 'rs'.$snp,"\t",$freq_a,"\n";
}


__END__


sub ReadHapMapFrequencies {
	my ($markers,$freq)=@_;
	my $population_no=$1 if $freq=~/hapmap_(\d+)/;
	$HM->PegOut ("Wrong format for frequency $freq") unless $population_no;
	my $sql=	"SELECT dbsnp_no, freq_hom FROM ".$HM->{prefix}."allelefrequencies WHERE dbsnp_no IN  (".join (",",('?') x @$markers).") 
			 AND population_no=?";
	my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
	$q->execute($population_no) || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
	$results=$q->fetchall_arrayref;
	foreach (@$results){
		
	




sub CreateMapFiles {
	my @regions=split /,/,shift;
	$HM->PegOut("No region specified.") unless (scalar @regions)>=3 ;
	$HM->PegOut("Something went wrong with the regions.") if (scalar @regions)%3 ;
	for (my $i=0;$i<=$#regions;$i+=3){ 
		push @sql, "chromosome=$regions[$i] AND position BETWEEN $regions[$i+2] AND $regions[$i+1]";
	}
	my $sql="SELECT chromosome, dbsnp_no, position FROM markers WHERE (".join (") OR (",@sql).') 
	AND dbsnp_no ORDER BY chromosome ASC, position ASC';
	my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
	$q->execute || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
	my $results=$q->fetchall_arrayref;
	$HM->PegOut("No suitable markers found!") unless @$results;
	my @markers=map {$_->[1]} @$results;
	open (OUT,'>','/tmp/map.map') || die ($!);
	print OUT join ("\t",'Chr','Probe Set ID','map'),"\n";
	foreach (@$results){
		print OUT join ("\t",@$_),"\n";
	}
	close OUT;
	return \@markers;
}

sub CreateGenotypesFile{
	my $markers=shift;
	my $sql="SELECT s.sample_no, sample_id FROM
		$HM->{data_prefix}samples_".$id." sa
		$HM->{data_prefix}samples_".$HM->{project_no}.' s WHERE s.sample_no=sa.sample_no';
	my %samples=();
	my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
	$q->execute () || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
	my $results=$q->fetchall_arrayref;
	foreach (@$results){
		$samples{$_->[0]}=$samples{$_->[1]};
	}
	my @samples=sort keys %sample;
	print join (", ",@samples),"<br>";
	
	
	$sql="SELECT m.dbsnp_no,sample_id,genotype FROM
		$HM->{data_prefix}samples_".$HM->{project_no}." s, $HM->{data_prefix}genotypes_".$HM->{project_no}." gt, 
		$HM->{markers_table} m,  $HM->{data_prefix}samples_".$id." sa
		WHERE s.sample_no=gt.sample_no
		AND sa.sample_no=s.sample_no
		AND gt.dbsnp_no=m.dbsnp_no
		AND m.dbsnp_no IN (".join (",",('?') x @$cases).") 
		ORDER BY m.dbsnp_no,sample_id";
	my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
	$q->execute (@$markers) || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
	my $results=$q->fetchall_arrayref;
	$HM->PegOut("No genotypes found!") unless @$results;
	my %gt;
	foreach (@$results){
		$gt{
		print OUT join ("\t",@$_),"\n";
	}
	open (OUT,'>','/tmp/genotypes.txt') || die ($!);
	
	
	close OUT;
	return \@markers;
}
		

sub ReadPedfile {
	my (%gt,%errors);
	my %recoded_alleles;
	open (PEDFILE,'<','/tmp/sample_pedfile.pro') || die($!);
	my $realdata=0;
	my @pedigree_members;
	while (<PEDFILE>){
		next if /^\s*#/;
		chomp;
		my @f=split /\s+/;
		next unless @f>4;
		push @pedigree_members,[@f];
	}
	close PEDFILE;
	die unless @pedigree_members;
	my $last_pm=scalar @pedigree_members-1;
}



__END__


use strict;
use lib '/www/lib/';
use HomozygosityMapper;
my $hm=new HomozygosityMapper;
my $dbh=$hm->{dbh};
my $q_microsat=$dbh->prepare("SELECT sts_name,chromosome,start_pos+(end_pos-start_pos)/2, duplicated FROM sts s, sts_36 pos WHERE 
s.sts_number=pos.sts_number AND sts_name=?") || die ($DBI::errstr);
my $q_snp=$dbh->prepare("SELECT dbsnp_no,chromosome,position FROM markers WHERE dbsnp_no=?") || die ($DBI::errstr);
my $dir=$ARGV[0] || '.';
my (%gt,%errors);
my %recoded_alleles;
open (PEDFILE,'<','pedfile2.pro') || die($!);
my $realdata=0;
my @pedigree_members;
while (<PEDFILE>){
	next if /^\s*#/;
	chomp;
	
	my @f=split /\s+/;
#	shift @f;
	next unless @f>4;
	#print $f[0],"\n";
	push @pedigree_members,[@f];
}
close PEDFILE;
die unless @pedigree_members;
my $last_pm=scalar @pedigree_members-1;

#die;
open (ERRORS,'<','../pedcheck.all') || print "No errors.\n";
while (<ERRORS>){
	if (/Name (SNP_A-\w+)/){
		$errors{$1}=1;
	}
}
close ERRORS;

opendir (DIR,$dir) || die($!);
my @files=grep /abi/, readdir DIR;
print join (", ",@files),"\n";
closedir DIR;
my %marker;

my $ok;
	my %freq;
foreach my $file (@files){
	my %count;

	open (GT,'<',$file) || die($!);
	print "$file...\n";
	my %recode;
	$_=(<GT>);
	my $recode=1;
	my $all=0;
	my $current_marker;
	while (<GT>){
		chomp;
		#Marker	LANE	ID	A_2	A_2
		my ($marker,undef,$id,@alleles)=split /\t/;
		$marker='D0S2251' if $marker eq 'D16S526';
		(@alleles)=sort @alleles[0..1];
		if ($alleles[0] && $alleles[1]){
			foreach my $i (0..1){
				my $allele=$alleles[$i];
				unless ($recode{$allele}){
					$recode{$allele}=$recode++;
				}
				$alleles[$i]=$recode{$allele};
				$count{$alleles[$i]}++;
				$all++;
			}
			$gt{$marker}->{$id}=[@alleles];
		}
		else {
			$gt{$marker}->{$id}=[(0,0)];
		}
		die if $current_marker && $current_marker ne $marker;
		$current_marker=$marker unless $current_marker;
		
		
	#			print join (",", keys %marker), "\n\n" if $file=~/753/;
	}
	close GT;
	my $results;
	if ($current_marker=~s/rs//){
		$q_snp->execute($current_marker) || die ($DBI::errstr);;
		$results=$q_snp->fetchall_arrayref() ;
		$current_marker='rs'.$current_marker;
	}
	elsif ($current_marker =~/D16Z8E/i){
		print "'$current_marker' ***\n" ;
			$results=[['D16SZ8E',16,56488213]];
		}

	else {
		$q_microsat->execute($current_marker) || die ($DBI::errstr);;
		$results=$q_microsat->fetchall_arrayref() ;
	}
	unless (@$results){

		  
		print "'$current_marker'\t$file\tnot found\n" ;
		
	}
	else {
		if (@$results>1){
			foreach my $resref (@$results){
				print join (", ",@$resref),"\n";
			}
			print ("too many results for $current_marker\n") ;
		}

		die ("ambigous") if $results->[0]->[3];
		$marker{$results->[0]->[1]}->{sprintf("%3.4f",$results->[0]->[2]/1000000)}=$current_marker;
	#	print "$current_marker\t$markerpos{$current_marker}->[1]\n" ;
	}
#	print "\n";
	$recoded_alleles{$current_marker}={%recode};
	foreach my $allele (keys %count){
		$freq{$current_marker}->{$allele}=sprintf("%1.6f",$count{$allele}/$all);
	}
#	print join (", ",%count),"\n";
#	print join (", ",%freq),"\n\n";

}


foreach my $chr (sort {$a <=> $b} keys %marker){
	print "CHR:$chr\n";


	#my @positions=grep {length $freq{$marker{$chr}->{$_}}} sort {$a <=> $b} keys %{$marker{$chr}};
	my @positions= sort {$a <=> $b} keys %{$marker{$chr}};

	my $number_of_markers=scalar @positions;
	my $sets=1;
	while (1==1){
		last if $number_of_markers/($sets)<120;
		last if $number_of_markers/($sets+1)<80;
		$sets++;
	}
	my $setsize=int($number_of_markers/$sets);
	print "$number_of_markers markers\t$sets\t$setsize\n";
	for my $set_no (1..$sets){
		my $setupfile=join ('.','setup',$chr,$set_no);
		my $pedfile=join ('.','ped',$chr,$set_no);
		my $outputfile=join ('.','output',$chr,$set_no);
		my $datafile=join ('.','datafile',$chr,$set_no);
		my $lastpos=0;
		my $i=0;
		
		my (@out,@diff,@genotypes);
		my $start_marker=($set_no-1)*$setsize-10;
		$start_marker=0 if $start_marker<0;
		my $end_marker=$set_no*$setsize+10;
		$end_marker=$number_of_markers-1 if $end_marker>($number_of_markers-1);
		if ($set_no==$sets) {
			$end_marker=$number_of_markers-1;
		}
		print "M $start_marker - $end_marker ($positions[$start_marker] - $positions[$end_marker])\n";
		my $markers_in_this_set=$end_marker-$start_marker+2;
		print "MARKERS: ",$end_marker-$start_marker,"\n";
		my $i3=0;
		
		open (DATAFILE,'>',$datafile) || die($!);
		print DATAFILE qq!$markers_in_this_set 0 0 5 << NO. OF LOCI, RISK LOCUS, SEXLINKED (IF 1) PROGRAM: GeneHunter
0.0 0.0 0 << MUT LOCUS, MUT RATE, HAPLOTYPE FREQUENCIES (IF 1)\n!;
print DATAFILE join (" ",(1..$markers_in_this_set)),"\n";
print DATAFILE qq!1  2 << AFFECTATION, NO. OF ALLELES
0.9990 0.0010 << GENE FREQUENCIES
1 << NO. OF LIABILITY CLASSES
0.0000 0.0000 0.9900 << PENETRANCE VECTOR\n!;
		my @markers;
		foreach my $i2 ($start_marker..$end_marker){
			my $pos=$positions[$i2];
			print "$start_marker / $i2 /$end_marker\n";
			
			my $diff=$pos-$lastpos;
			my $marker=$marker{$chr}->{$pos};
						print "C2" unless $gt{$marker};
			die unless $gt{$marker};
			push @markers,$marker;
	
			my @alleles=sort {$a <=> $b} keys %{$freq{$marker}};
			my $number_of_alleles=scalar @alleles ;
			print DATAFILE "3 $number_of_alleles # $marker - $chr:$pos  - ".join (", ",%{$recoded_alleles{$marker}})."\n";
			print DATAFILE join (" ",@{$freq{$marker}}{@alleles})."  << ALLELE FREQUENCIES\n";
 			print "LPM $last_pm\n";
			$i3++;

			$i++;
			push @diff,sprintf ("%1.3f",$diff) ;#if $i2>$start_marker;;
			$lastpos=$pos;
		
			
		}
		print "D: ",scalar @diff,"\n";
		print DATAFILE "0 0  << SEX DIFFERENCE, INTERFERENCE (IF 1 OR 2)\n";
		print DATAFILE join (" ",@diff),"  << RECOMB VALUES\n";
print DATAFILE "1 0.1 0.45  << REC VARIED, INCREMENT, FINISHING VALUE\n";
		print "chr $chr, $i / $i3 markers\n";
		open (OUT,'>',$pedfile) || die($!);
		foreach my $idref (@pedigree_members){
			my $sample=$idref->[1];
			print OUT join ("\t",@$idref);
			foreach my $marker (@markers){
				if ($gt{$marker}->{$sample}){
					print OUT "\t",join ("\t",@{$gt{$marker}->{$sample}});
				}
				else {
					print OUT "\t0\t0";
				}
			}
			print OUT "\n";
		}
		close OUT;


		
		PrintSetupFile($pedfile,$setupfile,$outputfile,$datafile);
	}
}


sub PrintSetupFile {
	my ($pedfile,$setupfile,$outputfile,$datafile)=@_;
	open (OUT,'>',$setupfile) || die ($!);
	print OUT 
qq!load markers $datafile

use
count recs on
single point off
haplo off
discard off
max bits 17
skip large off
analysis both
score all
letters off
off end
increment step 5
map function haldane
units cM
ps on
compute sharing on
scan $pedfile



total stat het








estimate






q


!;
	close OUT;
}