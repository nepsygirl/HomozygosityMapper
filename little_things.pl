#!/usr/bin/perl

use strict;

#---------------------------------------------------------------------------------------#

# mit diesem Regex kann man die Chr_N und Pos aus einer VCF-Zeile rausziehen.
# Geschlechtschromosomen sind dabei ausgeschlossen. 
# Mit "=~m/^\D*(\w+)[\s\t](\d+)/;" kann man sie einbeziehen(nur y/Y oder x/X, also nur 1 Buchstabe) 
# Dieser Regex versucht einige Format-Fehler zu "erkennen": irgendein Text vor oder nach der
# Chr_N; leerspace zwischen Chr und Pos(eventuell mehrmals oder abwechselnd mit Tab).

sub get_Chr_and_Pos
{
	shift =~ m/ ^\D* (\d+) \D*   [\s\t]+   (\d+)/x;
	return ($1,$2);
}

#---------------------------------------------------------------------------------------#

# Die recoded GT erstellen(Array, nach Samples geordnet)

sub get_recoded_GT 
{
	# die ersten 5 Spalten ziehen($1 = Ref, $2 = Alt).
	# der ([ACGT\.\,]*) steht zur Behebung von Format Fehlern.
	# in .tsv Datei(per Skype geschickt) steht ab und zu nichts in Alt Spalte
	# also z.B "CCCCTCCCTCCCTCCC		." der erste Fehler in der Datei.
	# man muss naturlich spater irgendwie lower/upper Case bearbeiten(eine Umformungsfunktion"lower=>upper" oder so)

	my $line = shift;

	# (]\d+:\d+])* steht fur: G]17:198982] oder ]13:123456]T oder aehnliches
	$line =~ m/^\w+ \t \d+ \t [\w\.]+ \t ([ACGT\.]+) \t (]\d+:\d+])*([ACGT\.\,]*)(]\d+:\d+])*\t/xi;

	# array mit verkuerzten GT(nach 4-bit Codierung, wie im Skype)
	# Alternative ganz unten

	my @Ref_Alt_array;
	my $ref_pos_1=substr($1,0,1);

	push (@Ref_Alt_array, $ref_pos_1);
	
	my $Alt = $3;
	my $alt_pos_1;

	$Alt=~m/[\w\.]+/g;

	do
	{
		$alt_pos_1 = substr($&,0,1);

		if ($ref_pos_1 ne $alt_pos_1)
		{
			$alt_pos_1 = "i";
		}
		push (@Ref_Alt_array, $alt_pos_1);
		
	}while ($Alt=~m/[\.\w]+/g);
	
	# Erstellung von recoded GT
	# das ist eine vereinfachte Version, da werden nur Homozygote wirklich recoded,
	# alle Heterozygote = 0. Man kann es aber erweitern und Hetero auch recodieren.

	# als values kann man auch bitstrings benutzen, falls es mit int nicht klappt
	my %GT_hash = ("." => 0, "i" => 1, "A" => 2, "C" => 3, "G" => 4, "T" => 5);
	my $i;
	my @recoded_GT;

	# mit g Modifier wird es ab letztem Match weiter nach dem nachsten gesucht, solange es matcht.
	# Jeder Match wird dann weiter in linke und rechte Seite zerlegt (also digits neben | oder /).
	# ein Array aus Integers(nur der rechteste Byte ist ausgefuellt) fur die DB Table wird erstellt,
	# dieser besteht aus 4 Byte Int's, die dann mithilfe von BIT Datentyp zu 1 Byte abgeschnitten
	# werden, hoffentlich.

	# leider funktioniert es falsch, wenn Format nicht stimmt(Tabs statt Eintragen, siehe .tsv in Skype)
	# ich denke es ist dann sehr aufwaendig alles richtig zu prozessieren, weil wenn die letzten Sample Spalten leer sind
	# dann uberspringt es zu der nachsten Zeile(es gibt also keine Zeichen(tabs), die darauf hinweisen, dass 
	# da etwas stehen muss.
	while ($line=~m/([\.\d]+)  [\/\|]  ([\.\d]+)/gx)
	{
		if ($1 eq $2)
		{
			$i = ($GT_hash{$Ref_Alt_array[$1]} << 1) | 1;
			push(@recoded_GT,$i," ");
		}
		else{push(@recoded_GT,0," ");}
	}

	return @recoded_GT;
}

#---------------------------------------------------------------------------------------

# .vcf als Input erwartet. Bei der ersten Schleife wird es solange durch die Zeilen gehen,
# bis es auf #CHROM-Zeile stoesst, diese wird auf die Korrektheit uberpruft.
# Je nachdem ob es korrekt ist oder nicht wird die weitere While-Schleife ausgefuhrt.

sub conv_VCF 
{
	open(my $fh, shift) or die "Could not open file";

	my $test = 1;
	while (<$fh>) 
	{
		# etwas geanderte Bedingung(original: /^#CHROM/). 
                # Falls statt CHROM sowas wie #CHR, chrom oder noch was falsches steht.
		if (/^#[^#]/)
		{
			unless (/^#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t.+/i)
			{
				$test=0;
				print "Falsches Format";
			}
			last;
		}
	}

	# Wenn die obere unless nicht ausgefuehrt wurde, ist $test == 1.
	# Alle Zeilen nach der Zeile "#CHROM POS ..." werden untersucht. 
	if ($test)
	{
		while (<$fh>) 
		{
			# hier kann man alles noetige bestimmen(chr,pos,GT) und in die DB pushen
			my @W=get_recoded_GT($_);
			
			print @W,"\n";
	 	}
	}
	close $fh;
}

foreach (@ARGV){
conv_VCF($_);}

#*
=alternative:
#  die ersten 2 Buchstaben pro Allel speichern(2-te Buchstabe kann i sein)
# so kann man immer noch die Homozygoten in einem Byte speichern
# fur Heterozygote ist es dann aber nicht so einfach(es sei denn man laesst sie weg)

	# zuerst den Ref in Array reinpushen.
	# falls der 3-te Buchstabe in Ref existiert => Stellen[2,3,...] als i(indel) markieren.

	my ($ref_pos_1,$ref_pos_2);
        if (substr($1,2,1))
	{
		# die ersten 2 Buchstaben aus Ref
		$ref_pos_1 = substr($1,0,1);
		$ref_pos_2 = "i";
		push (@Ref_Alt_array, $ref_pos_1 . "i");
	}
	else
	{
		push (@Ref_Alt_array, substr($1,0,2));
		# die ersten 2 Buchstaben aus Ref
		$ref_pos_1 = substr($1,0,1);
		$ref_pos_2 = substr($1,1,1);
	}

	# jetzt die Alt's in den array
	my ($alt_pos_1,$alt_pos_2);
	my $Alt = $2;
	
	$Alt=~m/[\.\w]+/g;
	do
	{
		# falls der 3-te Buchstabe in Alt existiert => Stellen[2,3,...] als i(indel) markieren.
		if (substr($&,2,1))
		{
			my $alt_pos_1 = substr($&,0,1);
			my $alt_pos_2 = "i";
		}
		else
		{
			my $alt_pos_1 = substr($&,0,1);
			my $alt_pos_2 = substr($&,1,1);
		}
		
		# Alt mit Ref vergleichen und Alt entsprechend modifizieren
		if ($ref_pos_1 ne $alt_pos_1)
		{
			$alt_pos_1 = "i";
		}

		if ($ref_pos_2 ne $alt_pos_2)
		{
			$alt_pos_2 = "i";
		}
		push (@Ref_Alt_array, $alt_pos_1 . $alt_pos_2);
		
	}while ($Alt=~m/[\.\w]+/g);
=cut
