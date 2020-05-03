#http://www.homozygositymapper.org/HM/CreateGenehunterFiles.cgi?analysis_no=85&regions=7,36547689,29786382&species=HomozygosityMapper=HASH(0xe3f300)-%3Especies

#!/usr/bin/perl

use strict;
use CGI;
use lib '/www/lib';
use HomozygosityMapper;

my $cgi=new CGI;
my $HM=new HomozygosityMapper;
my $fh = $cgi->upload('pedfile');
unless ($fh){
	$HM->PegOut("File could not be read.");
};
my $analysis_no=$cgi->param('analysis_no');
my $user_id=$HM->Authenticate;
my $unique_id=$cgi->param("unique_id") || 0;
$HM->QueryAnalysisName($analysis_no);
$HM->PegOut("Project unknown!") unless $HM->{project_name};
$HM->PegOut("No access to this project!") unless $HM->CheckProjectAccess($user_id,$HM->{project_no},$unique_id);

my $reg=$cgi->param("regions");
my @regions=split /,/,$reg;
$HM->PegOut("No region specified.") unless (scalar @regions)>=3 ;
$HM->PegOut("Something went wrong with the regions.") if (scalar @regions)%3 ;
my @sql=();
for (my $i=0;$i<=$#regions;$i+=3){ 
	push @sql, "chromosome=$regions[$i] AND position BETWEEN $regions[$i+1] AND $regions[$i+2]";
}




my $sql="SELECT dbsnp_no, chromosome, position FROM markers WHERE (".join (") OR (",@sql).') ORDER BY chromosome ASC, position ASC';
my $q=$HM->{dbh}->prepare($sql) || $HM->PegOut ("Internal error",{text=>[$sql,$DBI::errstr]});
$q->execute || $HM->PegOut ("Internal error (e)",{text=>[$sql,$DBI::errstr]});
my $genes=join (",",map { $_->[0]} @{$q->fetchall_arrayref});
$HM->PegOut("No genes found!") unless $genes;




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