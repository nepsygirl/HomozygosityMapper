use strict;
use 5.10.0;
my @samples=qw /1 2 3 4 5 6 7 8 9 10/;
my @affected_samples_indices=qw /3 5 7/; # sample 4,6,8 are affected
my %genotype=();
my $position=0;
for my $i (1..100) {  # take 100 positions
	$position+=int(rand(1e6)); # (random positions)
	foreach my $sample_index (0..$#samples) {  # for each sample
		$genotype{$position}->[$sample_index]=int(rand(16));  # assign a genotype between 0 and 15
	}
}

foreach my $position (sort keys %genotype) {  # now look at the positions
	say $position,":",CheckIdentity($genotype{$position}); # and test whether the affected samples are a) homozygous and b) have the same genotype
}

sub CheckIdentity {
	my $gt_ref=shift;
	my $gt=$gt_ref->[$affected_samples_indices[0]]; # genotype of first affected sample
	say $gt;
	return 0 if $gt>5; # not homozygous if the genotype > 5 (we neglect InDels with gt=5)
	foreach my $sample_index (@affected_samples_indices[1..$#affected_samples_indices]) { # look at the other samples; we start with the second...
		say $gt_ref->[$sample_index];
		next if $gt_ref->[$sample_index] == 0; # if there is no genotype at all it might be the identical;
		return 0 if $gt_ref->[$sample_index]>5; # not homozygous if the genotype > 5 (we neglect InDels with gt=5)
		$gt=$gt_ref->[$sample_index] if $gt ==0;  # if the first genotype is not defined, take this one
		return 0 if $gt_ref->[$sample_index] != $gt; # return if the genotypes are not the same;
	}
	return 1;
}