#!/usr/bin/perl

use strict;
use DBI;
use Time::HiRes qw( time );

# just a simple connection example
my $driver  = "Mem"; 
my $database = "postgres";
my $dsn = "DBI:$driver:dbname = $database;host = 127.0.0.1;port = 5432";
my $userid = "postgres";
my $password = "qwerty";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) 
   or die $DBI::errstr;

print "Opened database successfully\n";

# hier wird jede Zeile aus VCF in eine Zeile in DB gespeichert, also so: Chr  Pos  Sample1  GT1  Sample2  GT2 ...
# es lauft schon deutlich schneller, aber man muss da eventuell weiter optimieren
# ohne DB Insert: 10Mb ~ 1.5sec
# mit DB Insert: 10Mb ~ 25sec => optimieren

sub conv_VCF 
{
	open(my $fh, shift) or die "Could not open file";

	my $test_the_rest = 1;
	my $samples_n = 0;
	my $string1 = "";
	my $string2 = "?,?,";
	my $string3 = "";

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
				
				while($this_line =~ /[^\t]+/g)
				{
					$samples_n++;
					$string1 = $string1 . "Sample" . $samples_n . " SMALLINT," . "GT" . $samples_n . " INT,";
					$string2 = $string2 . "?" . "," . "?" . ",";
					$string3 = $string3 . "Sample" . $samples_n . "," . "GT" . $samples_n . ",";
				}
				chop $string2; chop $string3;

				my $table = qq(CREATE TABLE HomozygozityMapper
				     (Chr          SMALLINT,
				      Pos           INT,
				      $string1););
				my $rv = $dbh->do($table);
				if($rv < 0) {print $DBI::errstr;} 
				else {print "Table created successfully\n\n";}
			}
			last;
		}
	}

	# Wenn die obere unless nicht ausgefuehrt wurde, ist $test_the_rest == 1.
	# Alle Zeilen nach der Zeile "#CHROM POS ..." werden untersucht. 

my $u=0;
	if ($test_the_rest)
	{
		my ($Chr,$Pos,$Ref,$Alt,$GT); # scalars, in die Info aus VCF gespeichert wird.
		my @recoded_GT; # ein array fuer die recodierten Genotypen.
		my @Ref_Alt_array;
		my $alt_pos_1;

		# der rechteste Bit fur Homozygote(1), Heterozygote(0)
		my %GT_hash = ("." => 1, "A" => 5, "C" => 7, "G" => 9, "T" => 11, "N" => 3, "a" => 5, "c" => 7, "g" => 9, "t" => 11, "n" => 3, "*" => 1, "i" => 3);
		# die rows(enthalten Values fuer die DB), werden aneinandergehaengt($string). Laufzeit wird deutlich besser.
		#my $rows = qq(INSERT INTO HomozygozityMapper (Probe,Chr,Pos,GT,Length) VALUES (?,?,?,?,?););

		my $counter = 0;
		my $rows = qq/INSERT INTO HomozygozityMapper (Chr,Pos,$string3) VALUES ($string2)/;
		my $sth = $dbh->prepare($rows);

		# buffer and co
		my ($Chr_,$Pos_);
		my @recoded_GT_;
		my $done = 0;
		my @ar;
		while (<$fh>) 
		{
			if (/^(\w+)  \t  (\d+)  \t  [^\t]+  \t  ([^\t]+)  \t  ([^\t]+)   \t  [^\t]+  \t  [^\t]+  \t  [^\t]+  \t  [^\t]+  \t  (.+)/x)
			{
				#$Chr=$1;
				$Pos = $2;
				$Ref = $3;
				$Alt = $4;
				$GT  = $5;
				
				# Geschlechtschromosomen sind weg
				if ($1 =~ /\d+/) { $Chr = $&; }
				else { next; }
 
				# REF ueberpruefen
				# nur der erste Buchstabe wird untersucht und gespeichert.
				if ($Ref =~ /\.|[ACGTN]/i) 
				{ $Ref = $GT_hash{$&};
				  @Ref_Alt_array = ();
				  $Ref_Alt_array[0] = $Ref;}
				else { next; }

				# erst die Proben kontrollieren
				if ($GT =~ / ( [\.|\d+] [\|\/] [\.|\d+] [^\t]* \t? ) {$samples_n} /x)
				{
					# Die alternativen Allele
					if ($Alt =~ /(\.|[ACGTN\*])[ACGTN\*]*,?/ig)
					{
						if ( $Ref ne $GT_hash{$1} ) { push (@Ref_Alt_array, 3); }
						else { push (@Ref_Alt_array, $Ref_Alt_array[0]); }
						

						while ($Alt =~ /(\.|[ACGTN\*])[ACGTN\*]*,?/ig)
						{
							if ( $Ref ne $GT_hash{$1} ) { push (@Ref_Alt_array, 3); }
							else { push (@Ref_Alt_array, $Ref); }
						}
					}
					else { next; }

					# die GT rekodieren, Heterozygote sind alle 0, Homozygote sind ungerade wie oben in Hash. 
					# nicht case sensitive: "a" != "A" z.B
					@recoded_GT=();
				
					while ($GT=~m/ ((\.)|\d+)  [\/\|]  (\.|\d+)/gx)
					{
						if ($1 eq $3) # die beiden Allele sind gleich
						{
							if ($2) {push(@recoded_GT,1);} # falls es ein "."
							else { push(@recoded_GT, $Ref_Alt_array[$1]); }
						}
						else {push(@recoded_GT,0);}
					}
				}
				else { next; }  # man kann hier in ein Array die Nummer der falschen Zeilen speichern.


				if ($done)
				{
					$counter = 0;
					@ar = ();
					my $extra = $Pos - $Pos_;
					while ($counter ne $samples_n)
					{
						push(@ar, $recoded_GT_[$counter], $extra);			
						$counter++;
					}
					$sth ->execute($Chr, $Pos_, @ar);
				}
				else {$done = 1;}

				$Chr_ = $Chr;
				$Pos_ = $Pos;
				@recoded_GT_ = @recoded_GT;
			}
			else 
			{
				
				#print "Line ",$.," is broken, please fix it, otherwise incorrect result will be calculated.\n";
			}

			$u++;

			#if ($u == 3)
			#{last;}
	 	}
		# die letzte Zeile
		$counter = 0;
		@ar = ();
		while ($counter ne $samples_n)
		{
			push(@ar, $recoded_GT[$counter], 1);			
			$counter++;
		}
		$sth ->execute($Chr, $Pos_, @ar);
	}

	close $fh;
}


my ($time_begin,$end_time);
foreach (@ARGV){
$time_begin = time();
conv_VCF($_);
$end_time = time();}
printf("time: %.4f\n\n", $end_time - $time_begin);
=o
my $stmt = qq(SELECT Chr,Pos,Sample1,GT1,Sample2,GT2,Sample3,GT3,Sample4,GT4  from HomozygozityMapper;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
   print $DBI::errstr;
}

while(my @row = $sth->fetchrow_array()) {
#print @row ,"\n";
      print "Chr = ". $row[0] . "\n";
      print "Pos = ". $row[1] . "\n";
      print "S1 = ". $row[2] ."\n";
      print "GT1 = ". $row[3] ."\n";
      print "S2 = ". $row[4] ."\n";
      print "GT2 = ". $row[5] ."\n";
      print "S3 = ". $row[6] ."\n";
      print "GT3 = ". $row[7] ."\n";
      print "S4 = ". $row[8] ."\n";
      print "GT4 = ". $row[9] ."\n\n";

}
#=cut


=o
				if ($done)
				{
					$counter = 0;
					while ($counter != $samples_n)
					{

						if ($recoded_GT_[$counter]) { push (@push_it, $counter+1, $Chr_, $Pos_, $recoded_GT_[$counter], $Pos - $Pos_); }
						else { push (@push_it, $counter+1, $Chr_, $Pos_, $recoded_GT_[$counter], 0,); }
						$counter++;
					}
				}
				else {$done = 1;}
				$Chr_ = $Chr;
				$Pos_ = $Pos;
				@recoded_GT_ = @recoded_GT;

				if ($count eq 10000) 
				{
					$counter = 0;
					$count = $count * $samples_n;
					while ($count != 0)
					{
						$sth ->execute(@push_it[$counter..$counter+4]);
						$counter = $counter + 5;
						$count--;
					}
					@push_it = ();
				}
				$count++;
=cut
