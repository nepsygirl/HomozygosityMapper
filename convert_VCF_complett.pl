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

# create table

my $table = qq(CREATE TABLE HomozygozityMapper
     (Probe	   SMALLINT,
      Chr          SMALLINT,
      Pos           INT,
      GT            BIT,
      Length        INT););
my $rv = $dbh->do($table);
if($rv < 0) {
   print $DBI::errstr;
} else {
   print "Table created successfully\n";
}

#-------------#


# ohne DB Insert: 10Mb ~ 1sec
# mit DB Insert: 10Mb ~ 25sec => optimieren

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
				while($this_line =~ /[^\t]+/g)
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
		my ($Chr,$Pos,$Ref,$Alt,$GT); # scalars, in die Info aus VCF gespeichert wird.
		my @recoded_GT; # ein array fuer die recodierten Genotypen.
		my @Ref_Alt_array;
		my $alt_pos_1;

		# der rechteste Bit fur Homozygote(1), Heterozygote(0)
		my %GT_hash = ("." => 1, "i" => 3, "A" => 5, "C" => 7, "G" => 9, "T" => 11, "N" => 3, "a" => 5, "c" => 7, "g" => 9, "t" => 11, "n" => 3, "*" => 1);
		# die rows(enthalten Values fuer die DB), werden aneinandergehaengt($string). Laufzeit wird deutlich besser.
		#my $rows = qq(INSERT INTO HomozygozityMapper (Probe,Chr,Pos,GT,Length) VALUES (?,?,?,?,?););

		my $counter = 0;
		my $rows = qq/INSERT INTO HomozygozityMapper (Probe,Chr,Pos,GT,Length) VALUES (?,?,?,?,?)/;
		my $sth = $dbh->prepare($rows);

		# buffer and co
		my ($Chr_,$Pos_);
		my @recoded_GT_;
		my $done = 0;

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
 
				# Referenz ueberpruefen
				if ($Ref =~ /\.|[ACGTN]+/i) { $Ref = $&; }
				else { next; }

				# erst die Proben kontrollieren
				if ($GT =~ / ( [\.|\d+] [\|\/] [\.|\d+] [^\t]* \t{0,1} ) {$samples_n} /x)
				{
					# Die alternativen Allele
					if ($Alt =~ /\.|[ACGTN\*]+/ig)
					{
						@Ref_Alt_array = ();
						my $ref = substr($Ref,0,1);
						push (@Ref_Alt_array, $GT_hash{$ref});


						if ( $ref ne substr($&,0,1) ) { push (@Ref_Alt_array, 3); }
						else { push (@Ref_Alt_array, $Ref_Alt_array[0]); }
						

						while ($Alt =~ /\.|[ACGTN\*]+/ig)
						{
							if ( $ref ne substr($&,0,1) ) { push (@Ref_Alt_array, 3); }
							else { push (@Ref_Alt_array, $Ref_Alt_array[0]); }
						}
					}
					else { next; }

					# die GT rekodieren
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
					while ($counter ne $samples_n)
					{
						if ($recoded_GT_[$counter]){$sth ->execute($counter+1, $Chr, $Pos_, $recoded_GT_[$counter], $Pos - $Pos_);}
						else {$sth ->execute($counter+1, $Chr, $Pos_, $recoded_GT_[$counter], 0);}
						$counter++;
					}
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

			#if ($u == 2)
			#{last;}
	 	}
		# die letzte Zeile
		$counter = 0;

		while ($counter ne $samples_n)
		{
			if ($recoded_GT_[$counter]){$sth ->execute($counter+1, $Chr, $Pos_, $recoded_GT_[$counter], 1);}
			else {$sth ->execute($counter+1, $Chr, $Pos_, $recoded_GT_[$counter], 0);}
			$counter++;
		}
	}

	close $fh;
}


my ($time_begin,$end_time);
foreach (@ARGV){
$time_begin = time();
conv_VCF($_);
$end_time = time();}
printf("time: %.4f\n", $end_time - $time_begin);

=o
my $stmt = qq(SELECT Probe,Chr,Pos,GT,Length  from HomozygozityMapper;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
   print $DBI::errstr;
}


while(my @row = $sth->fetchrow_array()) {
#print @row ,"\n";
      print "Probe = ". $row[0] . "\n";
      print "Chr = ". $row[1] . "\n";
      print "Pos = ". $row[2] ."\n";
      print "GT = ". $row[3] ."\n";
      print "Length =  ". $row[4] ."\n\n";
}
=cut
