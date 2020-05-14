#!/usr/bin/perl

use strict;

use Time::HiRes qw( time );

# die einzelnen Funktionen aus little_things.pl werden kombiniert und ergaenzt
# formatfehler Handling durch Regex versucht


sub conv_VCF 
{
	open(my $fh, shift) or die "Could not open file";

	my $test_the_rest = 1;
	my $samples_n = 0;

	# uberprufe ob Metainfo und Header Teile(## und # Zeilen) richtig sind.
	while (<$fh>) 
	{
		if (/^[^#]/ || m/^#[^#]/)
		{
			unless (/^#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t(.+)/)
			{
				$test_the_rest=0;
				print "Wrong 'Metalines' or 'Header line' Format.";
			}

			# falls das Format passt, die Anzahl von Sapmles berechnen(spater fur Regex verwedet)
			if ($test_the_rest)
			{
				my $this_line = $1;
				while($this_line =~ /[^\t\s]+/g)
				{
					$samples_n++;
				}
			}
			last;
		}
	}

	# Wenn die obere unless nicht ausgefuehrt wurde, ist $test_the_rest == 1.
	# Alle Zeilen nach der Zeile "#CHROM POS ..." werden untersucht. 

my $u=0;
	if ($test_the_rest)
	{
		
		my ($Chr,$Pos,$Ref,$Alt,$GT);
		while (<$fh>) 
		{
			# teste Die Zeilen und ziehe die notwendige Info(Chr,Pos,Ref,Alt,GT).
			# Nach folgenden Formatregeln: https://samtools.github.io/hts-specs/VCFv4.2.pdf
			# case insensetive(i Modifier), weil z.B statt A das kleine a steht.
			# 
			# split(\t,$_) waere vielleicht ne bessere Idee, aber nur wenn das Format stimmt.
			# [^\.ACGTN\*]* ist fur "complex rearrangements with breakends" Behandlung
			# der Regex ist zwar ziemlich schwerwiegend, scheint aber richtig zu funktionieren.
			# 157 MB Datei (ohne DB Sachen) ~ 14 sec. Die Anzahl von Cores spielt keine Rolle(mit htop konnte man sehen, dass stets nur 1 Core beschaeftigt war)
			# vielleicht koennte man parallelisieren? man muss dann aber eventuell einen Dateibuffer erstellen und DB wird nicht geordnet sein.

			if (/^(\w+)  \t  (\d+)  \t  [^\t]+  \t  ([^\t]|[ACGTN]+)  \t  [^\.ACGTN\*]*(((\.|[ACGTN\*]+),{0,1})+)[^\.ACGTN\*]*   \t  [^\t]+  \t  [^\t]+  \t  [^\t]+  \t  [^\t]+  \t  (( (\.|\d+)[\|\/](\.|\d+) [^\t\s]* \t{0,1}){$samples_n})/xi)
			
			{
				$Chr = $1;
				$Pos = $2;
				$Ref = $3;
				$Alt = $5;
				$GT  = $9;
				
				# Geschlechtschromosomen kann man weglassen(eine if Bed. einsetzen, die sie dann uberspringt )
				$Chr =~ /\d+|[Yy]|[Xx]/;
				$Chr = $&;
				if ($Chr eq "Y" || $Chr eq "y"){$Chr = 23;}
				if ($Chr eq "X" || $Chr eq "x"){$Chr = 24;}

				my @Ref_Alt_array;
				my $ref_pos_1=substr($Ref,0,1);

				push (@Ref_Alt_array, $ref_pos_1." ");

				my $alt_pos_1;

				$Alt=~m/\.|[ACGTN*]+/g;

				do
				{
					$alt_pos_1 = substr($Alt,0,1);

					if ($ref_pos_1 ne $alt_pos_1)
					{
						$alt_pos_1 = "i";
					}
					push (@Ref_Alt_array, $alt_pos_1, " ");
					
				}while ($Alt=~m/\.|[ACGTN*]+/g);
				
				# der rechteste Bit fur Homozygote(1), Heterozygote(0)
				my %GT_hash = ("." => 1, "i" => 3, "A" => 5, "C" => 7, "G" => 9, "T" => 11, "a" => 5, "c" => 7, "g" => 9, "t" => 11);
				my $i;
				my @recoded_GT;

				while ($GT=~m/([\.\d]+)  [\/\|]  ([\.\d]+)/gx)
				{
					if ($1 eq $2)
					{
						$i = $GT_hash{$Ref_Alt_array[$1]};
						push(@recoded_GT,$i," ");
					}
					else{push(@recoded_GT,0," ");}
				}

					#print $Chr,"  ",$Pos," ",@Ref_Alt_array," ",@recoded_GT,"\n";
			}
			else 
			{
				
				#print "Line ",$.," is broken, please fix it, otherwise incorrect result will be calculated.\n";
			}

			# in DB insert!!!!!

			$u++;

			#if ($u == 10)
			#{last;}
	 	}
	}

	close $fh;
}

foreach (@ARGV){
my $time_begin = time();
conv_VCF($_);
my $end_time = time();
printf("time: %.4f\n", $end_time - $time_begin);}
