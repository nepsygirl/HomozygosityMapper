use strict;
use DBD::Pg ':async';
use DBI;
use CGI::Cookie;
use lib '/www/lib/';
package HomozygosityMapper;


sub new {
	my $class = shift;
	my $objectref = {species => shift};
	bless $objectref, $class;
	$objectref->Connect();
	$objectref->{rollback}={};
	$objectref->SetSpecies;
	return $objectref;
}

sub DESTROY {
    my $self = shift;
    return unless $self->{dbh};
    $self->{dbh}->rollback;
    $self->{dbh}->disconnect;
}

sub die2 {
	if ($_[0]=~/^HomozygosityMapper=HASH/){
		my $self=shift;
		$self->{dbh}->rollback if $self->{dbh};
		$self->PegOut(shift @_,{list=>\@_});
	}
	else {
		PegOut(undef,shift @_,{list=>\@_});
	}
}
$main::SIG{__DIE__} = \&die2;

sub Connect {
    my $self = shift;
    $self->{dbh} = DBI->connect(
        "dbi:Pg:dbname=postgres","USER-ID", "PASSWORD",
        { AutoCommit => 0, RaiseError => 0 }
    ) || $self->PegOut('DB error',{list=>$DBI::errstr});
}

sub Authenticate {
	my ($self,$user,$pass)=@_;
	unless ($user && $pass){
		my %cookies = fetch CGI::Cookie;
		if ($cookies{HomozygosityMapperAuth}){
			my ($line)=split /&/,$cookies{HomozygosityMapperAuth}->value;
			($user,$pass)=split /=/,$line;
		}
	}
	return 'guest' unless $user && $pass;
	my $q=$self->{dbh}->prepare("SELECT user_login,user_password,user_name,user_email,organisation FROM hm.users WHERE user_login=? AND user_password=?")
		|| $self->PegOut('DB error',{list=>$DBI::errstr});
	$q->execute($user,$pass) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$q=$q->fetchrow_arrayref();
	if (ref $q eq 'ARRAY' and $q->[0]){
		return $q->[0];
		$self->PegOut("Login problem",{list=>$q->[0]});
	}
	else {
		return 'guest';
	}
}

sub SetSpecies {
	my ($self,$species)=@_;
	$self->{species}=$species if $species;
	if ($self->{species} && $self->{species} ne 'human'){
		my $sub_call='SetSpecies_'.ucfirst $self->{species};
		$self->PegOut("Error",{list=>"Species <i>$self->{species}</i> is not implemented"}) unless $self->can($sub_call);
		$self->$sub_call;
		$self->{species_dir}='/'.$self->{species};
	}
	else {
		$self->{species}='human';
		$self->{species_dir}='';
		$self->SetSpecies_Human;
	}
}

sub CreateGenotypesTable {
	# creates the project table storing the genotypes
	print "Creating GT table...<br>";
	my ($self,$norawdata) = @_;
	my $index_pref=$self->{data_prefix};
	$index_pref=~s/\./_/g;
	my $tablename=$self->{data_prefix}.'genotypes_' . $self->{project_no} ;
	if ($self->{new}){
		my $sql  = qq !
		CREATE TABLE $tablename (
		dbsnp_no INTEGER,
		sample_no SMALLINT,
		genotype SMALLINT,
		block_length	SMALLINT,
			CONSTRAINT "pk_genotypes_!
		  .$index_pref.$self->{project_no}
		  . qq !" PRIMARY KEY (dbsnp_no, sample_no) ) !;
		$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
		$self->{rollback}->{tables}->{qq ! $self->{data_prefix}genotypes_! . $self->{project_no}}=1;  #;unless  $self->{data_prefix}=/dog/;
		$sql="CREATE INDEX i_".$index_pref."genotypes_" . $self->{project_no} .
		qq !_sample_no ON $self->{data_prefix}genotypes_! . $self->{project_no}.qq !
  			USING btree (sample_no)!;
  		$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>[$DBI::errstr,$sql]});
	}
	unless ($norawdata) {
		my	$sql  = qq !
		CREATE TABLE $self->{data_prefix}genotypesraw_! . $self->{project_no} . qq ! (
		dbsnp_no INTEGER,
		sample_no SMALLINT,
		genotype SMALLINT,
		CONSTRAINT "pk_genotypesraw_!
		  .$index_pref.$self->{project_no}
		  . qq !" PRIMARY KEY (dbsnp_no, sample_no) ) !;
		$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
		$self->{rollback}->{tables}->{qq ! $self->{data_prefix}genotypesraw_! . $self->{project_no}}=1;
		$sql="CREATE INDEX i_".$index_pref."genotypesraw_" . $self->{project_no} .
			qq !_sample_no ON $self->{data_prefix}genotypesraw_! . $self->{project_no}.qq !
  				USING btree (sample_no)!;
  			$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	}
	print "Genotype table(s) $self->{project_no} $tablename created!<br>";
}

sub CreateGenotypesTableVCF {
	# creates the project table storing the genotypes
	print "Creating VCF GT table...<br>";
	my ($self,$norawdata) = @_;
	my $index_pref=$self->{data_prefix};
	$index_pref=~s/\./_/g;
	if ($self->{new}){
		my $sql  = qq !
		CREATE TABLE $self->{data_prefix}vcfgenotypes_! . $self->{project_no} . qq ! (
		sample_no SMALLINT,
		chromosome SMALLINT,
		position INTEGER,
		genotype SMALLINT,
		block_length	SMALLINT,
			CONSTRAINT "pk_genotypes_!
		  .$index_pref.$self->{project_no}
		  . qq !" PRIMARY KEY (chromosome, position, sample_no) ) !;
		$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
		$self->{rollback}->{tables}->{qq ! $self->{data_prefix}vcfgenotypes_! . $self->{project_no}}=1;
		$sql="CREATE INDEX i_".$index_pref."vcfgenotypes_" . $self->{project_no} .
		qq !_sample_no ON $self->{data_prefix}vcfgenotypes_! . $self->{project_no}.qq !
  			USING btree (sample_no)!;
  		$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>[$DBI::errstr,$sql]});
	}
	unless ($norawdata) {
	my	$sql  = qq !
	CREATE TABLE $self->{data_prefix}vcfgenotypesraw_! . $self->{project_no} . qq ! (
		sample_no SMALLINT,
		chromosome SMALLINT,
		position INTEGER,
		genotype SMALLINT,
			CONSTRAINT "pk_vcfgenotypesraw_!
		  .$index_pref.$self->{project_no}
		  . qq !" PRIMARY KEY (chromosome, position, sample_no) ) !;
	$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{rollback}->{tables}->{qq ! $self->{data_prefix}vcfgenotypesraw_! . $self->{project_no}}=1;
	$sql="CREATE INDEX i_".$index_pref."vcfgenotypesraw_" . $self->{project_no} .
		qq !_sample_no ON $self->{data_prefix}vcfgenotypesraw_! . $self->{project_no}.qq !
  			USING btree (sample_no)!;
  		$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	}
	print "VCF genotype table(s) $self->{project_no} created!<br>";
}

sub Vacuum {
	# creates the project table storing the genotypes
	my $self = shift;
	my $table=shift;
	$self->Commit();
	$self->{dbh}->{AutoCommit} = 1;
	my $sql = "VACUUM ANALYZE $self->{data_prefix}".$table.'_' . $self->{project_no};
	$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{dbh}->{AutoCommit} = 0;
	print "VACUUMed $table $self->{project_no}!<br>";
}

sub NewProject {
	# creates the project table storing the genotypes
	my $self = shift;
	$self->{new} = 1;
}

sub DeleteTable {
	# creates the project table storing the genotypes
	my $self = shift;
	my $table = shift;
	my $sql  = "DROP TABLE $self->{data_prefix}".$table.'_' . $self->{project_no};
	$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	delete $self->{rollback}->{tables}->{$self->{data_prefix}.$table.'_' . $self->{project_no}};
	$self->Commit();
	print "Table $table $self->{project_no} deleted!<br>";
}


sub CreateResultsTable {
	# creates the *first* table storing results for this project,
	# more are possible for different analysis settings
	my $self = shift;
	my $analysis_no= shift;;
	$self->PegOut("Analysis_no not specified!") unless $analysis_no;
	my $table_name='results_' . $self->{project_no} . 'v'.$analysis_no;
	my $sql  = qq !
	CREATE TABLE $self->{data_prefix}$table_name (
	dbsnp_no INTEGER
		CONSTRAINT "pk_! . $table_name . qq !" PRIMARY KEY,
	hom_freq SMALLINT,
	hom_freq_ref SMALLINT,
	score SMALLINT) !;
	$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{rollback}->{tables}->{$self->{data_prefix}.$table_name}=1;
	return $self->{data_prefix}.$table_name;
}

sub CreateResultsTableVCF {
	# creates the *first* table storing results for this project,
	# more are possible for different analysis settings
	my $self = shift;
	my $analysis_no= shift;;
	$self->PegOut("Analysis_no not specified!") unless $analysis_no;
	my $table_name='vcfresults_' . $self->{project_no} . 'v'.$analysis_no;
	my $sql  = qq !
	CREATE TABLE $self->{data_prefix}$table_name (
	chromosome SMALLINT,
	position INTEGER,
	hom_freq SMALLINT,
	hom_freq_ref SMALLINT,
	score SMALLINT,
	CONSTRAINT "pk_! . $table_name . qq !" PRIMARY KEY (chromosome,position)) !;
	$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{rollback}->{tables}->{$self->{data_prefix}.$table_name}=1;
	return $self->{data_prefix}.$table_name;
}

sub CreateSamplesTable {
	# creates the table storing the project's samples
	# without any further information
	my $self = shift;
	my $sql  = qq !
	CREATE TABLE $self->{data_prefix}samples_! . $self->{project_no} . qq ! (
	sample_no	SMALLINT CONSTRAINT "pk_samples_!
	  . $self->{project_no}
	  . qq !" PRIMARY KEY,
	sample_id	VARCHAR(20)
		CONSTRAINT "u_samples_! . $self->{project_no} . qq !_sample_id" UNIQUE
		CONSTRAINT "nn_samples_! . $self->{project_no} . qq !_sample_id" NOT NULL) !;
	$self->{dbh}->do($sql) ||
		$self->PegOut("DB error",{list=>['Creation of samples table failed',$sql,$DBI::errstr]});
	$self->{rollback}->{tables}->{qq !$self->{data_prefix}samples_! . $self->{project_no}}=1;
	print "Samples table created.<br>\n";
}

sub CreateSamplesSubTable {
	# creates the table storing the project's samples
	# without any further information
	my $self = shift;
	my $sql  = qq !
	CREATE TABLE $self->{data_prefix}samples_! . $self->{project_no} . qq ! (
	sample_no	SMALLINT CONSTRAINT "pk_samples_!
	  . $self->{project_no}
	  . qq !" PRIMARY KEY,
	sample_id	VARCHAR(20)
		CONSTRAINT "u_samples_! . $self->{project_no} . qq !_sample_id" UNIQUE
		CONSTRAINT "nn_samples_! . $self->{project_no} . qq !_sample_id" NOT NULL) !;
	$self->{dbh}->do($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{rollback}->{tables}->{qq !$self->{data_prefix}samples_! . $self->{project_no}}=1;
}


sub _InsertNewProject {
	my ( $self, $project_name, $user_id, $access_restricted,$secret_key, $vcf_build ) = @_;
	my $project_no =
	  $self->{dbh}->prepare("SELECT nextval('".$self->{prefix}."sequence_projects')")
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$project_no->execute() || $self->PegOut('DB error',{list=>$DBI::errstr});
	$project_no = $project_no->fetchrow_arrayref->[0];
	$access_restricted=($access_restricted?'true':'false');
	my $date = sprintf ("%04d-%02d-%02d\n",((localtime)[5] +1900),((localtime)[4] +1),(localtime)[3]);
	my $insert = $self->{dbh}->prepare(
		"INSERT INTO ".$self->{prefix}."projects (project_no, project_name, user_login,
		access_restricted, unique_id, vcf_build, creation_date) VALUES (?,?,?,?,?,?,?)" )
		|| $self->PegOut('DB error',{list=>$DBI::errstr});
	$secret_key=undef unless $secret_key;
	$insert->execute( $project_no, $project_name, $user_id, $access_restricted, $secret_key, $vcf_build,$date)
	  || $self->PegOut('Could not insert project',{
	  		list=>[$project_no,$project_name,$user_id, $access_restricted, $secret_key, $vcf_build,$DBI::errstr]} );
	  print "<pre>$project_no, $project_name, $user_id, $access_restricted, $secret_key, $vcf_build,$date</pre>";
	$self->{rollback}->{inserts}->{$self->{prefix}."projects"}=['project_no',$project_no];
	$self->{project_no} = $project_no;
	$self->PegOut('DB error',{list=>'Project# could not be retrieved.'}) unless $self->{project_no};
	$self->{vcf}=$vcf_build;
}

sub CheckUser {
	my ($self,$user_login,$pending)=@_;
	my $q_user=$self->{dbh}->prepare("SELECT user_login FROM hm.users WHERE UPPER(user_login)=?") || $self->PegOut('DB error',{list=>$DBI::errstr});
	$q_user->execute(uc $user_login) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my $result=$q_user->fetchrow_arrayref;
	if (ref $result eq 'ARRAY' and @$result and $result->[0]){
		return 1;
	}
	if ($pending){
		my $q_user=$self->{dbh}->prepare("SELECT user_login FROM hm.new_users WHERE UPPER(user_login)=?") || $self->PegOut('DB error',{list=>$DBI::errstr});
		$q_user->execute(uc $user_login) || $self->PegOut('DB error',{list=>$DBI::errstr});
		my $result=$q_user->fetchrow_arrayref;
		if (ref $result eq 'ARRAY' and @$result and $result->[0]){
			return 2;
		}
	}
}

sub QueryProject {
	my ( $self, $project_name, $new,$user_id,$access_restricted, $secret_key, $vcf_build ) = @_;
	my $project_no = $self->{dbh}->prepare(
		"SELECT project_no FROM ".$self->{prefix}."projects WHERE UPPER(project_name)=?")
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$project_no->execute( uc $project_name ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$project_no = $project_no->fetchrow_arrayref;
	if ( ref $project_no eq 'ARRAY' && ! $new) {
		$self->{project_no} = $project_no->[0];
	}
	elsif ($new) {
		$self->_InsertNewProject($project_name,$user_id,$access_restricted,$secret_key, $vcf_build);
	}
}

sub InsertSamples {
	my ($self,$analysis_no,$cases,$controls)=@_;
	my $table_name=$self->CreateSamplesAnalysisTable($analysis_no);
	my $insert=$self->{dbh}->prepare("INSERT INTO $table_name (sample_no, affected) VALUES (?,?)")
		|| $self->PegOut("DB error",{list=>['Insert failed',"sample_no, affected",$DBI::errstr]});
	foreach my $case (@$cases){
		$insert->execute($case,'true') || $self->PegOut('',{list=>[$case,$DBI::errstr]});
	}
	foreach my $control (@$controls){
		$insert->execute($control,'false') || $self->PegOut('',{list=>[$control,$DBI::errstr]});
	}
}

sub GetState {
	my $self=shift;
	$self->PegOut('error',{list=>['project IDs missing', $self->{project_no} ,$self->{analysis_no}]})
		unless $self->{project_no} && $self->{analysis_no};
	my $id=$self->{project_no}.'v'.$self->{analysis_no};
	my $samples_sql="SELECT sample_id, affected FROM
		$self->{data_prefix}samples_".$self->{project_no}." s , "."$self->{data_prefix}samples_".$id." sa
		WHERE sa.sample_no=s.sample_no
		ORDER BY affected, sample_id";
	my $q=$self->{dbh}->prepare($samples_sql) || $self->PegOut('DB error',{list=>[$samples_sql,$DBI::errstr]});
	$q->execute || $self->PegOut('DB error',{list=>[$samples_sql,$DBI::errstr]});
	my $r=$q->fetchall_arrayref  || $self->PegOut('DB error',{list=>[$samples_sql,$DBI::errstr]});
	foreach (@$r) {
		my ($id,$state)=@$_;
		if ($state) {
			push @{$self->{cases}},$id;
		}
		else {
			push @{$self->{controls}},$id;
		}
	}
}

sub AnalysePerl {
	# much faster than Analyse()
	my $start=time();
	my ($self,$analysis_no,$allele_frequencies_from,$limit,$cases,$controls,$homogeneity_required,$lower_limit)=@_;
	$lower_limit=0 unless $lower_limit;
	my $max_score=0;
	if ($homogeneity_required){
		print "Homozygosity in <b>all</b> affected individuals is required...<br>";
	}
	else {
		print "Homozygosity in all affected individuals is <b>not</b> required...<br>";
	}
	print "block length limit: $limit<br>";
	print "lower limit: $lower_limit<br>";
	my $results_table_name=($self->{vcf}?$self->CreateResultsTableVCF($analysis_no):$self->CreateResultsTable($analysis_no));
	my $gt_table_name=$self->{data_prefix}.($self->{vcf}?'vcf':'').'genotypes_'.$self->{project_no};
	my (%cases);
	@cases{@$cases}=();
	my @controls_for_frequencies=();
	my $query_freq='';
	my $query_pop=0;
	my ($sql_q,$sql_i,$sql_af)=();
	if ($allele_frequencies_from eq 'controls'){
		unless (@$controls){
			$self->PegOut('Error',
			"No controls specified, how shall I use their frequencies?<br>.I can calculate extremely well but I don't have the second sight.") ;
		}
		@controls_for_frequencies=@$controls;
		if ($self->{vcf}){
			$sql_af="SELECT position, genotype, COUNT(*) FROM $gt_table_name
				WHERE chromosome=?
				AND sample_no IN (".join (",",('?') x @controls_for_frequencies).") GROUP BY position, genotype";
		}
		else {
			$sql_af="SELECT dbsnp_no, genotype, COUNT(*) FROM $gt_table_name
				WHERE dbsnp_no IN
				(SELECT dbsnp_no FROM $self->{markers_table} WHERE chromosome=?)
				AND sample_no IN (".join (",",('?') x @controls_for_frequencies).") GROUP BY dbsnp_no, genotype";
		}
		$query_freq=$self->{dbh}->prepare($sql_af) || die ($DBI::errstr);
	}
	elsif ($allele_frequencies_from=~/HapMap_(\d+)/i){
		$query_pop=$1;
		if ($self->{vcf}){
			$sql_af="SELECT position, freq_hom FROM ".$self->{prefix}."allelefrequencies	WHERE dbsnp_no IN
			(SELECT dbsnp_no FROM $self->{markers_table} WHERE chromosome=?) AND population_no=?";
		}
		else {
			$sql_af="SELECT dbsnp_no, freq_hom FROM ".$self->{prefix}."allelefrequencies	WHERE dbsnp_no IN
			(SELECT dbsnp_no FROM $self->{markers_table} WHERE chromosome=?) AND population_no=?";
		}
		$query_freq=$self->{dbh}->prepare($sql_af) || die ($DBI::errstr);
	}
	if ($self->{vcf}){
		$sql_q="SELECT position, sample_no, genotype, block_length FROM $gt_table_name
		WHERE chromosome=?
		AND sample_no IN (".join (",",('?') x (@$cases)).") ORDER BY position";
		$sql_i="INSERT INTO $results_table_name (chromosome,position, hom_freq, hom_freq_ref, score) VALUES (?,?,?,?,?)";
	}
	else {
		$sql_q="SELECT dbsnp_no, sample_no, genotype, block_length FROM $gt_table_name
		WHERE dbsnp_no IN
			(SELECT dbsnp_no FROM $self->{markers_table} WHERE chromosome=?)
		AND sample_no IN (".join (",",('?') x (@$cases)).") ORDER BY dbsnp_no";
		$sql_i="INSERT INTO $results_table_name (dbsnp_no, hom_freq, hom_freq_ref, score) VALUES (?,?,?,?)";
	}
	my $query=$self->{dbh}->prepare($sql_q) || $self->PegOut("DBerror",{list=>[$sql_q,$DBI::errstr]});
	my $insert=$self->{dbh}->prepare($sql_i) || $self->PegOut("DBerror",{list=>[$sql_i,$DBI::errstr]});
	my $i=0;
	my %not_all_hom=();
	foreach my $chromosome (1..$self->{max_chr}){
		print "Chromosome $chromosome...<br>\n";
		print "executing query<br>";
		my %lit_freq;
		if ($query_pop){
			$query_freq->execute($chromosome,$query_pop) || $self->PegOut("DBerror a",{list=>[$sql_af,$DBI::errstr]});
			my $freq_results=$query_freq->fetchall_arrayref;
			foreach (@$freq_results) {
				$lit_freq{$_->[0]}=$_->[1];
			}
		}
		elsif (@controls_for_frequencies){
			$query_freq->execute($chromosome,@controls_for_frequencies) || $self->PegOut("DBerror b",{list=>[$sql_af,$DBI::errstr]});
			my $freq_results=$query_freq->fetchall_arrayref;
			my %count_hom=();
			my %count_all=();
			foreach (@$freq_results) {
				if ($_->[1]==1 || $_->[1]==1){
					$count_hom{$_->[0]}=$_->[2];
					$count_all{$_->[0]}+=$_->[2];
				}
				if ($_->[1]==2){
					$count_all{$_->[0]}+=$_->[2];
				}
			}
			foreach my $dbsnp_no (keys %count_all){
				$lit_freq{$dbsnp_no}=$count_hom{$dbsnp_no}/$count_all{$dbsnp_no};
			}
		}
		$query->execute($chromosome,@$cases) ||  $self->PegOut("DBerror e",{list=>[$sql_q,join (",",$chromosome,@$cases),$DBI::errstr]});
		my (%count_cases_hom,%count_cases,%count_controls_hom,%count_controls,%score);
		my $results=$query->fetchall_arrayref  || die ($DBI::errstr);;
		my ($count_cases_hom,$count_cases,$score,$patient_not_homozygous)=(0,0,0,0);
		print scalar @$results, " genotypes on chromosome $chromosome $homogeneity_required<br>\n";
		for my $l (0..$#$results){
			my ($marker,$sample_no,$genotype,$block)=@{$results->[$l]};
			if (exists $cases{$sample_no}){
				if ($block){
					if ($block>$lower_limit){
						$score+=($block>$limit?$limit:$block);
					}
					if ($genotype==1 || $genotype==3){
						$count_cases_hom++;
					}
				}
				elsif ($homogeneity_required and $patient_not_homozygous==0) {
					$patient_not_homozygous=1;
				}
				$count_cases++;
			}
			if ($results->[$l+1]->[0] != $marker){
				my $freq_hom=$count_cases_hom/$count_cases;
				if ($patient_not_homozygous){
					$score=0;
					$patient_not_homozygous=0;
				}
				else {
					$max_score=$score if $score>$max_score;
				}
				$score=32766 if $score>32766;
				if ($self->{vcf}){
					$insert->execute($chromosome,$marker,sprintf("%2d",$freq_hom*1000),sprintf("%2d",$lit_freq{$marker}*1000),$score) || die ($DBI::errstr);
				}
				else {
					$insert->execute($marker,sprintf("%2d",$freq_hom*1000),sprintf("%2d",$lit_freq{$marker}*1000),$score) || die ($DBI::errstr);
				}

				$i++;
				($count_cases_hom,$count_cases,$score)=(0,0,0);
				unless ($i%50000){
					$self->iCommit($i);
					print "<small>$i inserts</small><br>\n";
				}
			}
		}
		$self->iCommit($i);
		print "<small>Chromosome $chromosome completed - $i inserts</small><br>\n";
	}
	return $max_score;
}

sub DifferentNumberOfGenotypes {
	my ($self,$gt_table,$samples)=@_;
	my $sql="SELECT COUNT(*) FROM $gt_table WHERE sample_no IN (".join (",",('?') x (@$samples)).") GROUP BY sample_no";
	my $q=$self->{dbh}->prepare($sql) || $self->PegOut("DBerror sgp",{list=>[$sql,$DBI::errstr]});
	$q->execute(@$samples) ||  $self->PegOut("DBerror sge",{list=>[$sql,join (",",@$samples),$DBI::errstr]});
	my $r=0;
	foreach (@{$q->fetchall_arrayref}){
		unless ($q) {
			$q=$_->[0];
		}
		else {
			return 1 unless $q==$_->[0];
		}
	}
	return 0;
}

sub AnalyseHomogeneity {
	# much faster than Analyse()
	my $start=time();
	my ($self,$analysis_no,$allele_frequencies_from,$limit,$cases,$controls,$lower_limit,$exclusion_length)=@_;
	$lower_limit=0 unless $lower_limit;
	my $max_score=0;
	print "<hr>AnalyseHomogeneity (2)<hr>\n";
	my $results_table_name=($self->{vcf}?$self->CreateResultsTableVCF($analysis_no):$self->CreateResultsTable($analysis_no));
	my $gt_table_name=$self->{data_prefix}.($self->{vcf}?'vcf':'').'genotypes_'.$self->{project_no};
	my (%cases);
	my (%controls);
	@cases{@$cases}=();
	@controls{@$controls}=();
	my ($sql_q,$sql_gt,$sql_i,$sql_af)=();
	if ($self->{vcf}){
		$sql_q=qq ! SELECT a.position,hom1,hom2 FROM (
		SELECT position FROM $gt_table_name WHERE chromosome=?
		GROUP BY position
		) a
		LEFT JOIN (
			SELECT position, COUNT(*) AS "hom1" FROM $gt_table_name
			WHERE sample_no IN (!.join (",",('?') x (@$cases)).qq !) AND genotype=1
			GROUP BY position) b
		on a.position=b.position
		LEFT JOIN (
			SELECT position, COUNT(*) AS "hom2" FROM $gt_table_name
			WHERE sample_no IN (!.join (",",('?') x (@$cases)).qq !) AND genotype=3
			GROUP BY position) c
		on a.position=c.position
		ORDER BY a.position
		!;  #'
		$sql_i="INSERT INTO $results_table_name (chromosome,position, hom_freq, score) VALUES (?,?,?,?)";
		if ($self->DifferentNumberOfGenotypes($gt_table_name,[@$controls,@$cases])){
			$sql_gt= qq ! SELECT position,genotype FROM $gt_table_name
				WHERE chromosome=? AND sample_no = ? ORDER BY position	!;
		}
		else {
			$sql_gt= qq ! SELECT a.position,genotype FROM (
				SELECT position FROM $gt_table_name
				WHERE chromosome=?
				GROUP BY position) a
				LEFT JOIN (
					SELECT position, genotype FROM $gt_table_name
					WHERE sample_no = ?
				) b
				on a.position=b.position 	ORDER BY a.position!;
		}
	}
	else {
		$sql_q= qq ! SELECT a.dbsnp_no,hom1,hom2 FROM (
		SELECT m.dbsnp_no, position FROM $gt_table_name g, $self->{markers_table} m
		WHERE m.dbsnp_no=g.dbsnp_no AND chromosome=?
		GROUP BY m.dbsnp_no, position
		) a
		LEFT JOIN (
			SELECT dbsnp_no, COUNT(*) AS "hom1" FROM $gt_table_name
			WHERE sample_no IN (!.join (",",('?') x (@$cases)).qq !) AND genotype=1
			GROUP BY dbsnp_no) b
		on a.dbsnp_no=b.dbsnp_no
		LEFT JOIN (
			SELECT dbsnp_no, COUNT(*) AS "hom2" FROM $gt_table_name
			WHERE sample_no IN (!.join (",",('?') x (@$cases)).qq !) AND genotype=3
			GROUP BY dbsnp_no) c
		on a.dbsnp_no=c.dbsnp_no
		ORDER BY position
		!; #'
		$sql_i="INSERT INTO $results_table_name (dbsnp_no, hom_freq, score) VALUES (?,?,?)";

		if ($self->DifferentNumberOfGenotypes($gt_table_name,[@$controls,@$cases])){
			$sql_gt= qq ! SELECT g.dbsnp_no, genotype FROM $gt_table_name g, $self->{markers_table} m
			WHERE m.dbsnp_no=g.dbsnp_no AND chromosome=? AND sample_no=?
			ORDER BY position	!;
		}
		else {
		# Achtung: das funktioniert NICHT, wenn es auf einem Chromosom unterschiedlich viele GTen in den Proben gibt...
			$sql_gt= qq ! SELECT a.dbsnp_no,genotype FROM (
			SELECT m.dbsnp_no, position FROM $gt_table_name g, $self->{markers_table} m
			WHERE m.dbsnp_no=g.dbsnp_no AND chromosome=?
			GROUP BY m.dbsnp_no, position
			) a
			LEFT JOIN (
				SELECT dbsnp_no, genotype FROM $gt_table_name
				WHERE sample_no = ?
			) b
			on a.dbsnp_no=b.dbsnp_no
					ORDER BY position	!;
		}
	}
	my $query=$self->{dbh}->prepare($sql_q) || $self->PegOut("DBerror p",{list=>[$sql_q,$DBI::errstr]});
	my $query_gt=$self->{dbh}->prepare($sql_gt) || $self->PegOut("DBerror gt p",{list=>[$sql_q,$DBI::errstr]});
	my $insert=$self->{dbh}->prepare($sql_i) || $self->PegOut("DBerror",{list=>[$sql_i,$DBI::errstr]});
	my $i=0;
	my %not_all_hom=();
	foreach my $chromosome (1..$self->{max_chr}){
		print "Chromosome $chromosome...<br><small>\n";
		my @reference_homozygosity=();
		my @markers=();
		my $starttime=time();
		my $starttime3=time();
		print "<b>Determining 'disease haplotype'...</b><br>\n";
		$query->execute($chromosome,@$cases,@$cases) ||  $self->PegOut("DBerror e1",{list=>[$sql_q,join (",","Chr".$chromosome,"Cases:",@$cases,"Controls:",@$controls),$DBI::errstr]});
		my (%count_cases_hom,%count_cases,%count_controls_hom,%count_controls,%score);
		my $starttime2=time();
		my $agg_results=$query->fetchall_arrayref  || die ($DBI::errstr);
		print scalar @$agg_results," SNPs...<br>\n";
		print "DB query took ",(time()-$starttime3)," seconds<br>\n";
		foreach my $agg_homozygosity (@$agg_results){
			push @reference_homozygosity,($agg_homozygosity->[1] > $agg_homozygosity->[2]?1:3);
			push @markers,$agg_homozygosity->[0];
		}
		print "Done!<br>";
		print "",(time()-$starttime2)," / ",(time()-$starttime)," seconds<br>\n";
		my @skip_positions=();
		undef $agg_results;
		my %blocks=();
		if ($exclusion_length>0){
			foreach my $sample (@$controls){
				my $starttime2=time();
				my $starttime3=time();
				print "<b>control sample $sample...</b><br>\n";
				$query_gt->execute($chromosome,$sample)  ||  $self->PegOut("DBerror e gt1",{list=>[$sql_q,join (",","Chr".$chromosome,"Sample:",$sample),$DBI::errstr]});
				my $results=$query_gt->fetchall_arrayref  || die ($DBI::errstr);
				print "DB query took ",(time()-$starttime3)," seconds<br>\n";
				print scalar @$results," genotypes <br>\n";
				my $pos=0;
				my $limit=$#$results;
				while ($pos <=$limit){
					if ($results->[$pos]->[1] == $reference_homozygosity[$pos]) {
						my $pos2=$pos;
						while ($results->[$pos2]->[1] == $reference_homozygosity[$pos2] and $pos2<=$limit){
							$pos2++;
						}
						my $blocklength=$pos2-$pos;
						for my $pos3 ($pos..($pos2-1)){
							unless ($skip_positions[$pos3]){
								$skip_positions[$pos3]=1 if $blocklength > $exclusion_length;
							}
						}
						$pos=$pos2;
					}
					else {
					$pos++;
					}
				}
				print (time()-$starttime2)," / ",(time()-$starttime)," seconds<br>\n";
			}
		}
		foreach my $sample (@$cases){
			print "<b>case sample # $sample...</b><br>\n";
			my $starttime2=time();
			my $starttime3=time();
			$query_gt->execute($chromosome,$sample)  ||  $self->PegOut("DBerror e gt1",{list=>[$sql_q,join (",","Chr".$chromosome,"Sample:",$sample),$DBI::errstr]});
			my $results=$query_gt->fetchall_arrayref  || die ($DBI::errstr);
			print "DB query took ",(time()-$starttime3)," seconds<br>\n";
			print scalar @$results," genotypes <br>\n";
			my @blocklength=();
			my $pos=0;
			my $limit1=$#$results;
			my $i0=0;
			while ($pos <=$limit1){
				$i0++;
				if ($results->[$pos]->[1]==2 or
					($results->[$pos]->[1] and $results->[$pos]->[1] != $reference_homozygosity[$pos])
					or $skip_positions[$pos]) {
					$blocklength[$pos]=0;
					$pos++;
				}
				else {
					my $pos2=$pos;
					while (
						$pos2<=$limit1
						and
						! _DetectBlockEndSameHomozygousBlockCases($results,\@reference_homozygosity,$pos,$pos2)
						and
						 ! $skip_positions[$pos2]){
						$pos2++;
					}
					my $blocklength=$pos2-$pos;
					for my $pos3 ($pos..($pos2-1)){
						$blocklength[$pos3]=$blocklength;
					}
					$pos=$pos2;
				}
			}
			$blocks{$sample}=\@blocklength;
			print "took ",(time()-$starttime2)," / ",(time()-$starttime)," seconds<br>\n";
		}
		my ($count_cases_hom,$count_cases,$score,$patient_not_homozygous,$controls_homozygous,$different_genotypes)=(0,0,0,0,0,0);
		MARKER:for my $l (0..$#markers){
			my $score=0;
			my $count_cases_hom=0;
			CASES: foreach my $sample (@$cases){
				if ($blocks{$sample}->[$l]){
					if ($blocks{$sample}->[$l]>$lower_limit){
						$score+=($blocks{$sample}->[$l]>$limit?$limit:$blocks{$sample}->[$l]);
					}
					$count_cases_hom++;
				}
				else {
					$score=0;
					last CASES;
				}
			}
			$max_score=$score if $score>$max_score;
			my $freq_hom=$count_cases_hom/@$cases;
			$i++;
			$score=32766 if $score>32766;
			if ($self->{vcf}){
				$insert->execute($chromosome,$markers[$l],sprintf("%2d",$freq_hom*1000),$score)
					||  $self->PegOut("DBerror e i1",{list=>[$sql_i,join (",",$chromosome,$markers[$l],sprintf("%2d",$freq_hom*1000),$score),$DBI::errstr]});
			}
			else {
				$insert->execute($markers[$l],sprintf("%2d",$freq_hom*1000),$score)
					||  $self->PegOut("DBerror e i2",{list=>[$sql_i,join (",",$markers[$l],sprintf("%2d",$freq_hom*1000),$score),$DBI::errstr]});
			}
		}
		print "<b>Chromosome $chromosome completed - $i inserts</b><br>\n";
		$self->iCommit($i);
		print "took ",(time()-$starttime)," seconds</small><br>\n";
	}
	return $max_score;
}

sub _DetectBlockEndSameHomozygousControls {
	my $min=6;
	my ($results,$genotypes,$start,$pos)=@_;
	return 1 unless $results->[$pos]->[1];
	return 1 if $results->[$pos]->[1]==2;
	return 1 if $results->[$pos]->[1]!=$genotypes->[$pos];
	return 1 unless $pos-$start>=$min;
	my $limit=$#$results-$pos;
	my $i=1;
	while ($i<=$min){
		if ($i<=$limit){
			return 1 if $results->[$pos+$i]->[1] and $results->[$pos+$i]->[1]!=$genotypes->[$pos+$i];
		}
		$i++;
	}
	return 0;
}

sub _DetectBlockEndOld {
	my $min=6;
	my ($results,$start,$pos)=@_;
	return 0 unless $results->[$pos]->[1]==2;
	return 1 unless $pos-$start>=$min;
	my $limit=$#$results-$pos;
	my $i=1;
	while ($i<=$min){
		if ($i<=$limit){
			return 1 if $results->[$pos+$i]->[1]==2;
		}
		$i++;
	}
	return 0;
}

sub _DetectBlockEndSameHomozygousBlockCases {
	my $min=6;
	my ($results,$genotypes,$start,$pos)=@_;
	#print LOG "D: $pos / $results->[$pos]->[1] / $block_length_controls->[$pos]\n";
	return 0 unless $results->[$pos]->[1] ;
	return 0 if $results->[$pos]->[1]==$genotypes->[$pos];
	return 1 unless $pos-$start>=$min;
	my $limit=$#$results-$pos;
	my $i=1;
	while ($i<=$min){
		if ($i<=$limit){
			return 1 if $results->[$pos+$i]->[1]==2 or ($results->[$pos+$i]->[1] and $results->[$pos+$i]->[1]!=$genotypes->[$pos+$i]);
		}
		$i++;
	}
	return 0;
}

sub QueryProjectName {
	my ( $self, $project_no) = @_;
	my $project_name = $self->{dbh}->prepare(
		"SELECT project_name FROM ".$self->{prefix}."projects WHERE project_no=?")
	  || die2("QPN $DBI::errstr");
	$project_name->execute( uc $project_no ) || die2("QPNe $DBI::errstr");
	$project_name = $project_name->fetchrow_arrayref;
	if ( ref $project_name eq 'ARRAY' ) {
		$self->{project_name} = $project_name->[0];
	}
}


sub SetMargin {
	my $self=shift;
	my $marker_count=$self->{marker_count};
	return 100000 if ($marker_count>800000);
	return 200000 if ($marker_count>500000);
	return 500000 if ($marker_count>250000);
	return 1000000;
}

sub QueryAnalysisName {
	my ( $self, $analysis_no) = @_;
		my $sql="SELECT p.project_no, project_name, analysis_name, analysis_description, max_block_length, max_score,
		access_restricted, allele_frequencies, user_login, marker_count, vcf_build, homogeneity_required,
		lower_limit, s.date, exclusion_length
		FROM ".$self->{prefix}."projects p,	".$self->{prefix}."analyses s
		WHERE s.project_no=p.project_no AND analysis_no=?";
	my $project_data =
	  $self->{dbh}->prepare($sql) || die2("QANp",$sql,$DBI::errstr);
	$project_data->execute($analysis_no)  || die2("QANe",$sql,$DBI::errstr);
	$project_data = $project_data->fetchrow_arrayref;
	if ( ref $project_data eq 'ARRAY' ) {
		$self->{project_no} = $project_data->[0];
		$self->{project_name} = $project_data->[1];
		$self->{analysis_name} = $project_data->[2];
		$self->{analysis_description} = $project_data->[3];
		$self->{max_block_length} = $project_data->[4];
		$self->{max_score} = $project_data->[5];
		$self->{access_restricted} = 'access restriced' if $project_data->[6];
		$self->{allele_frequencies} = $project_data->[7];
		$self->{user_login} = $project_data->[8];
		$self->{marker_count} = $project_data->[9];
		$self->{vcf_build} = $project_data->[10] if $project_data->[10];
		$self->{homogeneity_required} = 'homogeneity required' if $project_data->[11];
		$self->{lower_limit} = $project_data->[12];
		$self->{date} = $project_data->[13];
		$self->{exclusion_length} = $project_data->[14];
		return 1;
	}
	else {
		die2("Analysis unavailable.");
	}
}

sub CheckProjectAccess {
	my ($self,$user_id,$project_no,$unique_id)=@_;
	my @conditions=();
	my $sql="SELECT project_no, project_name, access_restricted, vcf_build FROM ".$self->{prefix}."projects WHERE ";
	if ($unique_id && $user_id eq 'guest'){
		$sql.=" unique_id = ?";
		@conditions=($unique_id);
	}
	else {
		if ($project_no){
			@conditions=($user_id,$project_no,$user_id,$project_no);
			$sql.=" unique_id IS NULL AND (((user_login=? OR access_restricted=false) 			AND project_no=?)
			OR project_no IN
				(SELECT project_no FROM ".$self->{prefix}."projects_permissions WHERE query_data='true' AND user_login=? AND project_no=?))
			";
		}
		else {
			@conditions=($user_id,$project_no,$user_id);
			$sql.=" unique_id IS NULL AND (
				(user_login=? OR access_restricted=false)
				AND project_no=? OR project_no IN
				(SELECT project_no FROM ".$self->{prefix}."projects_permissions WHERE query_data='true' AND user_login=?)
			)";
		}
	}
	my $query_projects=$self->{dbh}->prepare($sql) || die2("$DBI::errstr");
	$query_projects->execute(@conditions)  || die2("CPA $DBI::errstr",$sql);
	my $results=$query_projects->fetchrow_arrayref;
	if (ref $results eq 'ARRAY'){
		$self->{project_no}=$project_no;
		$self->{project_name}=$results->[1] unless $self->{project_name};
		$self->{vcf}=$results->[3];
		return 1 ;
	}
	die2("Sorry, you do not have access to this project.",'Please <A href="http://www.homozygositymapper.org/HM/login_form.cgi?species='.$self->{species}.'" target="_blank">login</A> first, go back and press reload / F5');
}

sub AllProjects {
	my ($self,$user_id,$own,$unique_id,$allow_uncompleted,$only_archived)=@_;
	my @conditions=$user_id;
	my $sql="SELECT project_no, project_name, access_restricted, user_login, vcf_build, marker_count, creation_date, genotypes_count FROM ".$self->{prefix}."projects
		WHERE  deleted IS NULL  AND archived IS ".($only_archived?'NOT':'')." NULL  AND user_login=? ";
	unless ($allow_uncompleted) {
		$sql.= " AND completed=true ";
	}
	if ($unique_id){
		$sql.= " AND unique_id=? ";
		push @conditions,$unique_id;
	}
	else {
		$sql.= " AND unique_id IS NULL ";
	}
	unless ($own || $unique_id){
		$sql.="	OR access_restricted=false OR project_no IN
		(SELECT project_no FROM ".$self->{prefix}."projects_permissions WHERE query_data='true' AND user_login=?) ";
		push @conditions,$user_id;
	}
#	$sql.=' ORDER BY UPPER(project_name) ';
	$sql.=' ORDER BY creation_date ';

	my $query_projects=$self->{dbh}->prepare($sql) || die2("$DBI::errstr");
	$query_projects->execute(@conditions)  || die2("APr $DBI::errstr",$sql);
	my $projectsref=$query_projects->fetchall_arrayref;
	return [] unless @$projectsref;
	my @own_projects=();
	my @other_projects=();
	foreach (@$projectsref){
		if ($_->[0]==46 || $_->[0]==200753){
			unshift @own_projects,$_;
		}
		elsif ($_->[3] eq $user_id){
			push @own_projects,$_;
		}
		else {
			push @other_projects,$_;
		}
	}
	return [(@own_projects, @other_projects)];
}




sub AllAnalyses {
	my ($self,$user_id,$own,$unique_id)=@_;
	my $sql="SELECT p.project_no, analysis_no, project_name, analysis_name, analysis_description,
	access_restricted, allele_frequencies,  max_block_length, user_login, marker_count, vcf_build, homogeneity_required,
	lower_limit, s.date, exclusion_length  FROM ".$self->{prefix}."projects p, ".$self->{prefix}."analyses s
	WHERE s.project_no=p.project_no  AND p.deleted IS NULL AND p.archived IS NULL AND s.deleted IS NULL AND s.archived IS NULL";
	my @conditions=();
	if ($unique_id){
		$sql.= " AND unique_id=? ";
		push @conditions,$unique_id;
	}
	else {
		$sql.= " AND unique_id IS NULL ";
		@conditions=$user_id;
		unless ($own){
			$sql.="	AND (user_login=? OR access_restricted=false OR p.project_no IN
		(SELECT project_no FROM ".$self->{prefix}."projects_permissions WHERE query_data='true' AND user_login=?)	)";
			push @conditions,$user_id;
		}
		else {
			$sql.="	AND user_login=? ";
		}
	}
	$sql.=" ORDER BY UPPER(project_name), UPPER(analysis_name)";
	my $query_projects=$self->{dbh}->prepare($sql) || die2("$DBI::errstr");
	$query_projects->execute(@conditions)  || die2("AP $DBI::errstr");
	my $projectsref=$query_projects->fetchall_arrayref;
	return [] unless @$projectsref;
	my @own_projects=();
	my @other_projects=();
	foreach (@$projectsref){
		if ($_->[1]==85){
			unshift @own_projects,$_;
		}
		elsif ($_->[1]==52822){
			unshift @own_projects,$_;
		}
		elsif ($_->[8] eq $user_id){
			push @own_projects,$_;
		}
		else {
			push @other_projects,$_;
		}
	}
	return [(@own_projects, @other_projects)];
}



sub AllUsers {
	my ($self)=shift;
	my $query_users=$self->{dbh}->prepare("SELECT user_login, user_name, user_email FROM hm.users ORDER BY user_login") || die2("$DBI::errstr");
	$query_users->execute()  || die2("AP $DBI::errstr");
	return $query_users->fetchall_arrayref;
}

sub GetPermissions {
	my ($self)=shift;
	my $options=shift;
	my @conditions;
	my $sql="SELECT project, user_login, read, analysis FROM ".$self->{prefix}."project_permissions";
	my $query_users=$self->{dbh}->prepare($sql )  || die2("AP $DBI::errstr");
}



sub QueryMarkers {
	# returns all markers for a given chip type
	# blows up memory use but is faster than a query for each single marker
	# not used for Illumina chips - all SNPs in the file will be written to disk
	# the analysis sub will only use those listed in the DB
	my $self = shift;
	my $sql="SELECT marker_name,dbsnp_no FROM ".$self->{prefix}."markers2chips WHERE chip_no=?";
	unless ($self->{new}){
		$sql.=" OR dbsnp_no IN (SELECT DISTINCT(dbsnp_no) FROM ".$self->{data_prefix}."genotypes_".$self->{project_no}.")";
		print "Oh, this is an existing project. We'll have to extract the markers in use then. Might take a while if many genotypes are stored.<br>";
	}
	my $q_markers = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$q_markers->execute( $self->{chip_no} ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{markers} = $q_markers->fetchall_hashref('marker_name');
	print scalar keys %{$self->{markers}}," markers identified by vendor ID in use...<br>";
}

sub ReadAffymetrix {
	# reads Affymetrix genotypes and writes them to the DB
	my ( $self, $fh ) = @_;
	my $sql =
	    qq !INSERT INTO $self->{data_prefix}genotypesraw_!
	  . $self->{project_no}
	  . ' (dbsnp_no,sample_no,genotype)	VALUES (?,?,?)';
	my $insert = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$_ = <$fh>;
	my $output;
#	if (/MPAM Mapping Analysis/){
#		$_ = <$fh>;
#	}
	print "First line (ReadAffymetrix):<br>'$_'<br>$sql<br>";
#	if ( /^Probeset ID/ || /^ID/ || /^SNP.ID/ || /Mapping Analysis/i ) {
		my $pass = $_ unless /Mapping Analysis/;
		$output=$self->_ReadOldFile( $fh,$insert, $pass );
#	}
#	else {
#		$output=$self->_ReadNewFile($fh,$insert);
#	}
	close $fh;
	return $output;
}

sub _ReadOldFile {
	# reads old Affymetrix genotype file (BRLMM)
	# Probenzuordnung!
	my @output;
	print "Type: Affymetrix file<br>OldFile<br>";
	my ( $self, $fh,$insert,$passed ) = @_;
	my %default = (
		'ID'                => 1,
		'SNP_ID'            => 1,
		'SNP ID'            => 1,
		'CHROMOSOME'          => 1,
		'TSC ID'            => 1,
		'PHYSICAL POSITION' => 1,
		'PHYSICAL.POSITION' => 1,
		'DBSNP RS ID'       => 1,
		'CHROMOSOMAL POSITION'=> 1,
		'CONFIDENCE'=> 1,
		'SIGNAL A'=> 1,
		'SIGNAL B'=> 1,
		'FORWARD STRANDBASE CALLS'=> 1,
	);
	$_ =  $passed || <$fh>;
	while ($_=~/^#/){
		$_=(<$fh>);
	}
	my $starttime = scalar time();
	s /\W+$//;
	s /Call Codes\t/Call Codes Sample1\t/gi;
	s/Probe.*set.ID/SNP ID/i; # Affy like to change their format way too often
	s /SNP.{0,1}ID/SNP ID/i;    # some people insert underscores -> get rid of them!
	s /SNP.{0,1}NAME/SNP ID/i;    # some people insert underscores -> get rid of them!
	s /(?!\t).Call/Call/ig;
	s /_Mendel//ig;
	s /\tCBE_\w+?_/\t/g;
	my (@filecolumns2) = split /\t/;
	my ( @samples, @filecolumns ) = ();
	s /_Sty_/_/gi;
	s /_Nsp_/_/gi;
#	if (/CBE_/) {
#		# get rid of the stupid coding schema used by the CCG
#		@samples =
#		  grep { s/CBE_\w+?_(.*)_\w+?[ _.]+Call/$1/gi } @filecolumns2;
#		@filecolumns =
#		  map { s/CBE_\w+?_(.*)_\w+?[ _.]+Call/$1/gi; $_ } @filecolumns2;
#	}
	if (/_Call Zone/i) {
		@samples = grep { s/(.+)_Call$/$1/i } @filecolumns2;
		@filecolumns = map { s/(.+)_Call$/$1/i; $_ } @filecolumns2;
	}
	elsif (/_Call/i) {
		@samples = grep { s/(.+)_*\w*?_Call/$1/i } @filecolumns2;
		@filecolumns = map { s/(.+)_*\w*?_Call/$1/i; $_ } @filecolumns2;
	}
	elsif (/Call Codes/i) {
		@samples = grep { s/Call Codes (.+)/$1/i } @filecolumns2;
		@filecolumns = map { s/Call Codes (.+)/$1/i; $_ } @filecolumns2;
	}
	else {
		@samples = grep { not exists $default{ uc $_ } } @filecolumns2;
		@filecolumns = map { s/(.+)_\w+?_Call/$1/i; $_ } @filecolumns2;
	}
	@filecolumns=map {s/Probeset ID/SNP ID/;$_} @filecolumns;
	@samples=grep {length $_} map {s /\W+$//;$_} @samples;
	print "FC: ".join (", ",@filecolumns),"<br>\n";
	print "Samples: ".join (", ",@samples),"<br>\n";
	$self->_InsertSamples( \@samples );
	my %samples = %{ $self->{samples} };
	die2("No samples") unless keys %samples;

	my $inserted=0;
	my $skipped=0;
	my %done;
	while (<$fh>) {
		s /\W+$//;
		s/\tNoCall/\t-1/g;
		s/\tAA/\t0/g;
		s/\tAB/\t1/g;
		s/\tBA/\t1/g;
		s/\tBB/\t2/g;
		my (@fields) = split /\t/;    #,lc $_;
		my %fields;
		@fields{@filecolumns} = @fields;
		unless ( $. % 10000 ) {
			print "line $. / $inserted genotypes inserted.<br>\n";
		}
		next unless $fields{'SNP ID'};
		$fields{'SNP ID'}=~s/SNP_A-0/SNP_A-/;
		my $dbsnp_no = $self->{markers}->{ $fields{'SNP ID'} }->{dbsnp_no};
		unless ($dbsnp_no) {
			unless ($skipped < 100 ){
				push @output,  $skipped++. " SNP $fields{'SNP ID'} not in DB - skipped!\n";
			}
		}
		elsif ($done{$dbsnp_no}){
			print " SNP $fields{'SNP ID'} (rs $dbsnp_no) is redundant - second occurrence was skipped.<br>";
		}
		else {
			$done{$dbsnp_no}=1;
			foreach my $sample (@samples) {
				$self->PegOut('Wrong format',{list=>["Genotype for sample '$sample' in line $. coded as '$fields{$sample}'","line $.:'$_'",join (",",%fields)]}) unless $fields{$sample}=~/^-*\d+$/;
				my $ins= $insert->execute( $dbsnp_no, $samples{$sample},			$fields{$sample}+1 ) ;

				$self->PegOut("Could not insert genotype",	{list=>["dbSNP $dbsnp_no", "Sample $sample ($samples{$sample})","GT $fields{$sample}","line $_",$DBI::errstr]}) unless $ins;
				$inserted += $ins;
	#				 $insert->execute( $dbsnp_no, $samples{$sample}, $fields{$sample} ) || CheckGenotype($self,$dbsnp_no, $samples{$sample}, $fields{$sample},$insert, $DBI::errstr);

				unless ( $inserted % 50000 ) {
					$self->iCommit($inserted);
					print "line $. / $inserted genotypes inserted.<br>\n";
				}
			}
		}
	}
	if ($skipped){
		unshift @output,"$skipped markers were not found in the database. Only the first 100 are shown.<br>";
	}
	unless ($inserted){
		$self->PegOut("Nothing written to DB",{
			list=>["Typical reasons:","data in a wrong format",
			"wrong array selected",'',@output,"samples:",join (", ",@samples)]});
	}
	else {
		push @output, "$inserted genotypes inserted.\n";
		my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}."projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
		$insert_marker_count->execute(scalar keys %done,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
		return \@output;
	}
}

sub _ReadNewFile {
#	die ("Not possible due to software update...");
	print "New file<br>";
	my $skipped=0;
	my ( $self, $fh,$insert ) = @_;
	my @output;
#	push @output, "BRLMM algorithm.\n";
	my @samples       = ();
	my (@filecolumns) = ();
	my %samples       = ();
	my $inserted;
	my %done;
	while (<$fh>) {
		s /\W+$//;
		if (/^probeset/) {
			@filecolumns = map { basename($_) } split /\t/;
			if (/CBE/i) {
				s /Mendel_//gi;
				@samples = grep { s/CBE_\w+?_(.*?)_\d+?_.*/$1/gi } @filecolumns;
			}
			else {
				s /Mendel_//gi;
				@samples = grep { s/(.+)_\w+?_Call/$1/i } @filecolumns;
			}
					@samples=grep {
			lc ($_) ne 'dbsnp rs id' && lc($_) ne 'chromosome'
		&& lc($_) ne 'physical position' && lc($_) ne 'tsc id'} @samples;
			$self->_InsertSamples( \@samples );
			%samples = %{ $self->{samples} };
			die2 ("Could not gather samples",$_) unless @samples;
			die2("No samples") unless keys %samples;
			print "Samples: ".join (", ",keys %samples),"<br>\n";
		}
		next unless @samples;

		my @fields = split /\t/;    #,lc $_;
		my %fields;
		@fields{@filecolumns} = @fields;

		next unless $fields{'probeset_id'};
		$fields{'probeset_id'}=~s/SNP_A-0/SNP_A-/;
		my $dbsnp_no =
		  $self->{markers}->{ $fields{'probeset_id'} }->{dbsnp_no};
		unless ($dbsnp_no) {
			push @output, $skipped++. " SNP $fields{'SNP ID'} not in DB - skipped!\n";
			next;
		}
		if ($done{$dbsnp_no}){
			print " SNP $fields{'SNP ID'} (rs $dbsnp_no) is redundant - second occurrence was skipped.<br>";
		}
		else {
			$done{$dbsnp_no}=1;
		foreach my $sample (@samples) {
			$inserted +=
			  $insert->execute( $dbsnp_no, $samples{$sample},	$fields{$sample} + 1 )
			  || die2(	join( ",", $dbsnp_no, $samples{$sample}, $fields{$sample} ),"\n", $DBI::errstr );
			unless ( $inserted % 50000 ) {
				$self->iCommit($inserted);
				print "line $. / $inserted genotypes inserted.<br>\n";
			}
		}
	}
	}
	unless ($inserted){
		die2("Nothing written to DB","samples",@output,%samples);
	}
	else {
		push @output, "Inserted genotypes: $inserted\n";
		my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}."projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
		$insert_marker_count->execute(scalar keys %done,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
		return \@output;
	}
}


sub ReadIllumina {
#die ("ILLUM");
	# reads Illumina genotypes and writes them to the DB
	#SNP_ID	1859	1860	1861	1862	1863	1864	1865	1868
	#rs1867749	AB	AA	AB	AA	AA	AA	AB	AB
	#rs1397354	BB	BB	BB	BB	BB	BB	BB	BB

	my ( $self, $fh ) = @_;
	print "reading Illumina genotypes file...<br>\n";
	my $sql =
	    qq !INSERT INTO $self->{data_prefix}genotypesraw_!
	  . $self->{project_no}
	  . qq ! (dbsnp_no,sample_no,genotype)	VALUES (?,?,?)! ;  #?
	my $insert = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my $headings=<$fh>;

	chomp $headings;
	$headings=~s /\W+$//;
	unless ($headings=~s/^SNP.ID\t//i or $headings=~s/^\t// or $headings=~s/^dbsnp\t//i){
		die2("Header not ok","The first line <b>has to</b> start with either SNP*ID, dbSNP or an empty field<br>(* can be any character) and the fields must be tab delimited.","First line: '".$headings."'");
	}
	my @output;
	my %done;
	my @samples=split /\t/,$headings;
	$self->_InsertSamples( \@samples );
	my %samples = %{ $self->{samples} };
	my $inserted=0;
	while (<$fh>){
		next if /^cnvi/i;
		chomp;
		unless ( $. % 10000 ) {
			$self->iCommit($inserted);
			print "$.\t$inserted genotypes inserted.<br>\n";
		}
		s /\W+$//;
		s/--/0/g;
		s/AA/1/g;
		s/AB/2/g;
		s/BA/2/g;
		s/BB/3/g;
		s/\t00/\t0/g;
		my ($dbsnp_no,@gt)=split /\t/;
	#	print "$self->{chip_no} 'DB1 $dbsnp_no'<br>\n" if $self->{chip_no}>10;
		unless ($dbsnp_no=~s/^rs//){
			if ( $self->{markers}->{$dbsnp_no}->{dbsnp_no}){
				$dbsnp_no = $self->{markers}->{$dbsnp_no}->{dbsnp_no};
				unless ($dbsnp_no) {
					push @output, "SNP ",(split /\t/)[0]," skipped";
					next ;
				}
			#	if (ref $dbsnp_no eq 'HASH'){
			#		print "DBA ".join (",",%$dbsnp_no)."<br>\n";
			#	}
			#	print "'DB $dbsnp_no' x '$self->{markers}->{$dbsnp_no}'<br>\n";
			}
			else {
		  		push @output, "SNP $dbsnp_no skipped";
				next ;
			}
		}
		if ($done{$dbsnp_no}){
			print " SNP $dbsnp_no is redundant - second occurrence was skipped.<br>";
		}
		else {
			$done{$dbsnp_no}=1;
		for my $i (0..$#gt){
			$inserted +=
			  $insert->execute( $dbsnp_no, $samples{$samples[$i]},
				$gt[$i] )
			  || CheckGenotype($self,$dbsnp_no, $samples{$samples[$i]},
				$gt[$i],$insert,$DBI::errstr);
			unless ( $inserted % 50000 ) {
				$self->iCommit($inserted);
				print "line $. / $inserted genotypes inserted.<br>\n";
			}
		}
	}

	}
	close $fh;
	print "$inserted genotypes inserted.<br>";
	push @output,"$inserted genotypes inserted.";
	unless ($inserted){
		$self->PegOut("Nothing written to DB","samples",@samples);
	}
	my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}."projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	$insert_marker_count->execute(scalar keys %done,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	return \@output;
}

sub GetAllVariantsPositions {
	my $self=shift;
	my $chromosome=shift;
	my %markers=();
	print "reading known variants on chromosome $chromosome from the database...<br>\n";
	my $sql="SELECT position FROM ".$self->{markers_table}." WHERE chromosome=? ORDER BY position ";
	my $q=$self->{dbh}->prepare ($sql)  || $self->PegOut("DBerror",{list=>[$sql,$DBI::errstr]});
	$q->execute($chromosome) || $self->PegOut("DBerror",{list=>[$sql,"chr: $chromosome,$chromosome",$DBI::errstr]});
	my $r=$q->fetchall_arrayref();
	foreach my $r (@$r){
		$markers{$r->[0]}=1;
	}
	print "read ",scalar keys %markers," known variants on chromosome $chromosome from the database...<br>\n";
	return \%markers;
}

sub ReadVCF {
	my ( $self, $fh, $min_cov, $source ) = @_;
	print "uploading VCF file, minimum coverage: $min_cov, variations: $source<br>";
	my $marker_count=0;
	my $sql =
	    qq !INSERT INTO $self->{data_prefix}vcfgenotypesraw_!
	  . $self->{project_no}
	  . qq ! (sample_no,chromosome,position,genotype) VALUES (?,?,?,?)!;
	my $insert = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my @output;
	my %done;
	my $inserted=0;
	my $start=0;
	my @samples=();
	my $last_index=0;
	my $snp_count=0;
	my $last_chromosome;
	my $markers=();
	$min_cov=10 unless length $min_cov;
	my %samples=();
#	my $counter=0;
#	open (DOMI,'>','/tmp/domi2.tmp');;
	while (<$fh>){
		if (/^#CHROM/){
			$start=1;
			chomp;
			s /\W+$//;
			#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	/opt/NGS/analyses/2011_06_14_Jana_Dinc/S1_sorted.bam	/opt/NGS/analyses/2011_06_14_Jana_Dinc/S2_sorted.bam	/opt/NGS/analyses/2011_06_14_Jana_Dinc/S3_sorted.bam	/opt/NGS/analyses/2011_06_14_Jana_Dinc/S3old_sorted.bam	/opt/NGS/analyses/2011_06_14_Jana_Dinc/S4_sorted.bam
			@samples=split /\t/;
			unless (/^#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t.+/){
				$self->PegOut("VCF format not ok",{
					list=>['columns <b>must</b> be CHROM, POS, ID, REF, ALT, QUAL, FILTER, INFO, FORMAT, samples [tab delimited]'],
					text=>["your line looks this:<pre>$_</pre>"]});
			}
			$last_index=$#samples;
			@samples=map {s /.*[\/\\]//; s /\.bam//i; $_ } @samples[9..$last_index];
			print "Samples are ".join (",",@samples).".<br>\n";
			$self->_InsertSamples( \@samples );
			%samples = %{ $self->{samples} };
		}
		elsif ($start){
		#	print "$.<br>\n" unless $.%1000;
			chomp;
			unless ( $. % 10000 ) {
				$self->iCommit($inserted);
				print "line $. / $inserted genotypes inserted.<br>\n";
			}
			my ($chrom,$position,$alt,$formatstring,@genotypes)=(split /\t/)[0,1,4,8,(9..$last_index)];
			next unless $chrom=~/\d+/;
		#	if ($alt=~/,/){
		#		print "$chrom:$position has two alt alleles: $alt. Since the genotypes are not discriminated in the VCF file, this position is skipped.<br>\n";
		#		next;
		#	}
			$chrom=~s/^chr//i;
			if ($chrom=~/\D/){
				print "Chromosome $chrom found in line $. - ignoring this line.<br>\n" unless $chrom eq 'X' or $chrom eq 'Y' or $chrom eq 'MT';
				next;
			}
			if ($chrom != $last_chromosome){
				print "<b>line $. / $inserted genotypes inserted so far, now switching to chromosome $chrom.<br></b>\n";
				if ($chrom<$last_chromosome) {
					$self->PegOut('File not ordered',{
						list=>["Chromosome $chrom appears after $last_chromosome (line $.)"],
						text=>["For a better performance, HomozygosityMapper2 requires VCF file to be ordered by chromosome"]});
				}
				$marker_count+=scalar keys %done;
				$markers=$self->GetAllVariantsPositions($chrom) unless $source eq 'variants';
				%done=();
				$last_chromosome=$chrom;
			}
			if ($done{$position}){
				print " position $position - second occurrence was skipped.<br>";
			}
			else {
				my $gt=1 if (grep {/:/} @genotypes);

#				print $gt;
				next unless (		($source eq 'variants' and $gt)
					or ($source eq 'dbSNP' and exists $markers->{$position})
					or ($source eq 'all' and (exists $markers->{$position} or $gt )));

#				if (exists $markers->{$position} or grep {/\//} @genotypes ){
#				if ( grep {/\//} @genotypes ){
				#	my $known_variant=(exists $markers->{$position}?1:0);
#					Pre($known_variant.': '.join (", ",@genotypes).' #'.$last_index);
					my @data=split /:/,$formatstring;
	#				my @out;
					my @recoded_genotypes=();
					for my $i (0..$#samples){
						my %gt_data;
						@gt_data{@data}=split /:/,$genotypes[$i];

			#			push @out, "'$gt_data{GT}' ($gt_data{DP})";
						if ($gt_data{DP}>=$min_cov){
		#					$counter++;
							my @alleles=split /\D/,$gt_data{GT};
							$done{$position}=1 unless $done{$position}=1;
							if ($gt_data{GT} eq '' or $gt_data{GT} =~ /^0.0$/){
								push @recoded_genotypes,1;
							}
							elsif ($gt_data{GT} =~ /^1.1$/){
								push @recoded_genotypes,3;
							}
							elsif ($alleles[0] != $alleles[1]){
								push @recoded_genotypes,2;
							}
							else {
								push @recoded_genotypes,0;
							}
						}
						else {
							push @recoded_genotypes,0;
						}
					#							print "<pre>$gt_data{DP}:$gt_data{GT}:$recoded_genotypes[-1]</pre>" if rand(1)>.99;
					}
					if ($done{$position}){
						for my $i (0..$#samples){
							$insert->execute($samples{$samples[$i]},$chrom,$position, $recoded_genotypes[$i]) || $self->PegOut("DBerror",{list=>[$DBI::errstr,$sql,"$samples{$samples[$i]},$chrom,$position,  $recoded_genotypes[$i]"]});
							$inserted ++;
							unless ( $inserted % 50000 ) {
								$self->iCommit($inserted);
								print "line $. / $inserted genotypes inserted.<br>\n";
							}
						}
					}
#					Pre ($out);
		#		}
			}
		}
	}
	close $fh;
	$marker_count+=scalar keys %done;
	print "$inserted genotypes inserted.<br>";
	push @output,"$inserted genotypes inserted.";
	unless ($inserted){
		$self->PegOut("Nothing written to DB","samples",@samples);
	}
	my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}.
		"projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	$insert_marker_count->execute($marker_count,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	return \@output;
}

sub Pre {
	print "<pre>",join ("\n",@_),"</pre>\n";
}

sub ReadIllumina_NF {
	my ( $self, $fh ) = @_;
	print "Illumina, new format...<br>\n";
	my $sql =
	    qq !INSERT INTO $self->{data_prefix}genotypesraw_!
	  . $self->{project_no}
	  . qq ! (dbsnp_no,sample_no,genotype)	VALUES (?,?,?)!; #?
	my $insert = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my $headings=<$fh>;

	chomp $headings;
	$headings=~s /\W+$//;
	if ($headings=~s/^SNP.ID\t//){
	}
	elsif ($headings=~s/^\t//){
	}
	elsif ($headings=~s/^dbsnp\t//i){
	}
	else {
		die2("Header not ok","The first line <b>has to</b> start with either SNP*ID, dbSNP or an empty field<br>(* can be any character) and the fields must be tab delimited.",$headings);
	}
	my @output;
	my %done;
	my @samples=split /\t/,$headings;
	$self->_InsertSamples( \@samples );
	my %samples = %{ $self->{samples} };
	my $inserted=0;
	while (<$fh>){
	#	print "$.\n" unless $.%10000;
		chomp;
		s /\W+$//;
		s/--/0/g;
		s/\t00/\t0/g;
		my ($dbsnp_no,@gt)=split /\t/;
		unless ($dbsnp_no=~s/^rs//){
			$dbsnp_no = $self->{markers}->{ $dbsnp_no }->{dbsnp_no};
			unless ($dbsnp_no) {
				push @output, "SNP ",(split /\t/)[0]," skipped";
				next ;
			}
		}
		if ($done{$dbsnp_no}){
			print " SNP rs $dbsnp_no is redundant - second occurrence was skipped.<br>";
		}
		else {
			$done{$dbsnp_no}=1;
			chomp;
			my %gt;
			@gt{@gt}=();
			delete $gt{0};
			die ("Too many different genotypes, only 3 different genotypes (plus 0) are possible: ",join (",",keys %gt)) if scalar keys %gt>3;
			my %alleles;
			foreach my $gt (keys %gt){
				next if $gt eq '0';
				die ("Illegal genotype '$gt': Genotypes must consist of two letters (A/B/C/G/T) or be coded as 0") unless $gt=~/^[ABCGT]{2}$/;
				@alleles{split //,$gt}=();
			}
			die ("Too many alleles: ",join (",",keys %alleles),". Only 2 different alleles are allowed.") if scalar keys %alleles>2;
			my @alleles=sort keys %alleles;
			@gt=map {
				$_=join ("",sort {$a cmp $b} split //,$_);
				s /$alleles[0]$alleles[0]/1/;
				s /$alleles[0]$alleles[1]/2/;
				s /$alleles[1]$alleles[1]/3/;
				$_} @gt;
			for my $i (0..$#gt){
				$inserted +=
					$insert->execute( $dbsnp_no, $samples{$samples[$i]},
				$gt[$i] )
				|| CheckGenotype($self,$dbsnp_no, $samples{$samples[$i]},
				$gt[$i],$insert,$DBI::errstr);
				unless ( $inserted % 50000 ) {
					$self->iCommit($inserted);
					print "line $. / $inserted genotypes inserted.<br>\n";
				}
			}
		}
		unless ( $. % 10000 ) {
			$self->iCommit($inserted);
			print "$.\t$inserted genotypes inserted.<br>\n";
		}
	}
	close $fh;
	print "$inserted genotypes inserted.<br>";
	push @output,"$inserted genotypes inserted.";
	unless ($inserted){
		$self->PegOut("Nothing written to DB","samples",@samples);
	}
	my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}.
		"projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	$insert_marker_count->execute(scalar keys %done,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	return \@output;
}

sub ReadIllumina_NonHuman {
#die ("ILLUM");
	# reads Illumina genotypes and writes them to the DB
	#SNP_ID	1859	1860	1861	1862	1863	1864	1865	1868
	#rs1867749	AB	AA	AB	AA	AA	AA	AB	AB
	#rs1397354	BB	BB	BB	BB	BB	BB	BB	BB
	#SNP NAME	1859	1860	1861	1862	1863	1864	1865	1868
	print "<pre>ReadIllumina_NonHuman</pre>";
	my ( $self, $fh ) = @_;
	my $sql =
	    qq !INSERT INTO $self->{data_prefix}genotypesraw_!
	  . $self->{project_no}
	  . ' (dbsnp_no,sample_no,genotype)	VALUES (?,?,?)';
	my $insert = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my $headings=<$fh>;
	chomp $headings;
	$headings=~s /\W+$//;
	$headings=~s/SNP\.NAME/SNP NAME/;
	my $snp_column='';
	unless ($headings=~s/^(SNP.*?)\t//i or $headings=~s/^\t// or $headings=~s/^(dbsnp)\t//i){
		die2("Header not ok","The first line <b>has to</b> start with either SNP*, dbSNP or an empty field<br>(* can be any character) and the fields must be tab delimited.","First line: '".$headings."'");
	}
	$snp_column=uc $1;
	my @output;
	my %done;
	my @samples=split /\t/,$headings;
	$self->_InsertSamples( \@samples );
	my %samples = %{ $self->{samples} };
	my $inserted=0;
	while (<$fh>){
		next if /^cnvi/i;
		chomp;
		s /\W+$//;
		s/--/0/g;
		s/AA/1/g;
		s/AB/2/g;
		s/BA/2/g;
		s/BB/3/g;
		s/\t00/\t0/g;
		my ($dbsnp_no,@gt)=split /\t/;
		if ($snp_column eq 'SNP NAME'){
			if ($self->{markers}->{ $dbsnp_no }->{dbsnp_no}) {
				$dbsnp_no = $self->{markers}->{ $dbsnp_no }->{dbsnp_no}
			}
			else {
				print "Marker $dbsnp_no not in DB!<br>" if $.<20;
				$dbsnp_no=0;
			}
		#	print "Marker "scalar keys %{$self->{markers}},"<br>" if $.<20;
			next unless $dbsnp_no;
		#	print scalar keys %{$self->{markers}},"<br>" if $.<20;
		}
		if ($dbsnp_no=~/\D+/) {
			print " line $. - SNP $dbsnp_no could not be found in the database.<br>";
		}
		elsif ($done{$dbsnp_no}){
			print " SNP $dbsnp_no is redundant - second occurrence was skipped.<br>";
		}
		else {
			$done{$dbsnp_no}=1;
			for my $i (0..$#gt){
				$inserted +=
				  $insert->execute( $dbsnp_no, $samples{$samples[$i]},
					$gt[$i] )
				  || CheckGenotype($self,$dbsnp_no, $samples{$samples[$i]},
					$gt[$i],$insert,$DBI::errstr);
				unless ( $inserted % 50000 ) {
					$self->iCommit($inserted);
					print "line $. / $inserted genotypes inserted.<br>\n";
				}
			}
		}
		unless ( $. % 10000 ) {
			$self->iCommit($inserted);
			print "$.\t$inserted genotypes inserted.<br>\n";
		}
	}
	close $fh;
	print "$inserted genotypes inserted.<br>";
	push @output,"$inserted genotypes inserted.";
	unless ($inserted){
		$self->PegOut("Nothing written to DB","samples",@samples);
	}
	my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}."projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	$insert_marker_count->execute(scalar keys %done,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	return \@output;
}

sub ReadIllumina_NonHuman_NF {
	my ( $self, $fh ) = @_;
	my $sql =
	    qq !INSERT INTO $self->{data_prefix}genotypesraw_!
	  . $self->{project_no}
	  . qq ! (dbsnp_no,sample_no,genotype)	VALUES (?,?,?)!;
	my $insert = $self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my $headings=<$fh>;
	chomp $headings;
	$headings=~s /\W+$//;
	$headings=~s/SNP\.NAME/SNP NAME/;
	my $snp_column='';
	unless ($headings=~s/^(SNP.*?)\t//i or $headings=~s/^\t// or $headings=~s/^(dbsnp)\t//i){
		die2("Header not ok","The first line <b>has to</b> start with either SNP*, dbSNP or an empty field<br>(* can be any character) and the fields must be tab delimited.","First line: '".$headings."'");
	}
	$snp_column=uc $1;
	my @output;
	my %done;
	my @samples=split /\t/,$headings;
	$self->_InsertSamples( \@samples );
	my %samples = %{ $self->{samples} };
	my $inserted=0;
	while (<$fh>){
		next if /^cnvi/i;
		chomp;
		s /\W+$//;
		s/--/0/g;
		s/\t00/\t0/g;
		my ($dbsnp_no,@gt)=split /\t/;
		if ($snp_column eq 'SNP NAME'){
			$dbsnp_no = $self->{markers}->{ $dbsnp_no }->{dbsnp_no};
			next unless $dbsnp_no;
		#	print scalar keys %{$self->{markers}},"<br>" if $.<20;
		}
		if ($done{$dbsnp_no}){
			print " SNP $dbsnp_no is redundant - second occurrence was skipped.<br>";
		}
		else {
			$done{$dbsnp_no}=1;
			chomp;
			my %gt;
			@gt{@gt}=();
			delete $gt{0};
			die ("Too many different genotypes, only 3 different genotypes (plus 0) are possible: ",join (",",keys %gt)) if scalar keys %gt>3;
			my %alleles;
			foreach my $gt (keys %gt){
				next if $gt eq '0';
				die ("Illegal genotype '$gt': Genotypes must consist of two letters (A/B/C/G/T) or be coded as 0") unless $gt=~/^[ABCGT]{2}$/;
				@alleles{split //,$gt}=();
			}
			die ("Too many alleles: ",join (",",keys %alleles),". Only 2 different alleles are allowed.") if scalar keys %alleles>2;
			my @alleles=sort keys %alleles;
			@gt=map {
				$_=join ("",sort {$a cmp $b} split //,$_);
				s /$alleles[0]$alleles[0]/1/;
				s /$alleles[0]$alleles[1]/2/;
				s /$alleles[1]$alleles[1]/3/;
				$_} @gt;
			for my $i (0..$#gt){
				$inserted +=
				  $insert->execute( $dbsnp_no, $samples{$samples[$i]},
					$gt[$i] )
				  || CheckGenotype($self,$dbsnp_no, $samples{$samples[$i]},
					$gt[$i],$insert,$DBI::errstr);
				unless ( $inserted % 50000 ) {
					$self->iCommit($inserted);
					print "line $. / $inserted genotypes inserted.<br>\n";
				}
			}
		}
		unless ( $. % 10000 ) {
			$self->iCommit($inserted);
			print "$.\t$inserted genotypes inserted.<br>\n";
		}
	}
	close $fh;
	print "$inserted genotypes inserted.<br>";
	push @output,"$inserted genotypes inserted.";
	unless ($inserted){
		$self->PegOut("Nothing written to DB","samples",@samples);
	}
	my $insert_marker_count = $self->{dbh}->prepare("UPDATE ".$self->{prefix}."projects SET marker_count=? WHERE project_no=?" ) ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	$insert_marker_count->execute(scalar keys %done,$self->{project_no})  ||  $self->PegOut('DB error',{list=>$DBI::errstr});
	return \@output;
}

sub CheckGenotype {
	my ($self,$dbsnp_no, $sample_no,$gt,$insert,$old_error)=@_;
	return unless $gt;
	if ($old_error=~/duplicate key value violates unique constraint "pk_genotypesraw/ ){  #"
		die2("ERROR","Sorry, you must not upload genotypes already stored in the database!",
		"Please check whether you accidentally tried to re-upload a file or whether one of your
		individuals appears in the old data with genotypes fors the same marker.");
	}
	$self->PegOut(qq *'$gt' is not an allowed genotype. Please refer to <A HREF="http://www.homozygositymapper.org/sample_files.html">
	http://www.homozygositymapper.org/sample_files.html</A> for accepted formats. *) unless $gt=~/[01239]/;
	my $sql="SELECT genotype FROM ".$self->{data_prefix}."genotypesraw_".$self->{project_no}.
		" WHERE dbsnp_no=? AND sample_no=?";
	my $q=$self->{dbh}->prepare($sql) || die2("CG qp",$sql,$dbsnp_no,$sample_no,'old:'.$old_error,$DBI::errstr);
	$q->execute($dbsnp_no, $sample_no) || die2("CG qe",$sql,$dbsnp_no,$sample_no,'old:'.$old_error,$DBI::errstr);
	$gt=$q->fetchrow_arrayref->[0];
	die2("CG ee",$gt,'old:'.$old_error,$DBI::errstr);
	#die (qq ! $gt[$i] is not an allowed genotype. Please refer to
	#		<A HREF="http://www.homozygositymapper.org/sample_files.html">http://www.homozygositymapper.org/sample_files.html</A> for accepted formats.!)
}

sub _InsertNewChip {
	my ( $self, $chip, $manufacturer ) = @_;
	my $chip_no = $self->{dbh}->prepare("SELECT MAX(chip_no) FROM ".$self->{prefix}."chips")
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$chip_no->execute() || $self->PegOut('DB error',{list=>$DBI::errstr});
	$chip_no = $chip_no->fetchrow_arrayref->[0] + 1;
	my $insert =
	  $self->{dbh}->prepare(
		"INSERT INTO ".$self->{prefix}."chips (chip_no, chip_name, manufacturer) VALUES (?,?,?)"
	  ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$insert->execute( $chip_no, $chip, $manufacturer ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$self->{chip_no} = $chip_no;
}

sub QueryChip {
	my ( $self, $chip, $manufacturer, $new ) = @_;
	my $chip_no =
	  $self->{dbh}
	  ->prepare("SELECT chip_no FROM ".$self->{prefix}."chips WHERE UPPER(chip_name)=?")
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$chip_no->execute( uc $chip ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$chip_no = $chip_no->fetchrow_arrayref;
	if ( ref $chip_no eq 'ARRAY' ) {
		$self->{chip_no} = $chip_no->[0];
	}
	elsif ($new) {
		$self->_InsertNewChip( $chip, $manufacturer ) unless $chip_no;
	}
}

sub AllChips {
	my ( $self ) = shift;
	my $sth =  $self->{dbh}->prepare(
		"SELECT chip_no, chip_name, manufacturer FROM ".$self->{prefix}."chips ORDER BY manufacturer, chip_name")
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$sth->execute( ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	return $sth->fetchall_arrayref;
}



sub CheckChipNumber {
	my ( $self, $chip ) = @_;
	my $sql="SELECT chip_no,chip_name,manufacturer FROM ".$self->{prefix}."chips WHERE chip_no=?";
	my $chip_q =
	  $self->{dbh}
	  ->prepare($sql)
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$chip_q->execute($chip ) || $self->PegOut('DB error',{list=>$DBI::errstr});
	my $chip_data = $chip_q->fetchrow_arrayref;

	if ( ref $chip_data eq 'ARRAY' and $chip_data->[0]) {
		$self->{chip_no}=$chip;
		$self->{chip_name}=$chip_data->[1];
		$self->{chip_manufacturer}=$chip_data->[2];
		#print STDERR "ERR $sql: $chip";
	#	print STDERR "ERR $self->{chip_no},$self->{chip_name},$self->{chip_manufacturer}";
		return 1;
	}
	else {
#		die ("$sql: $chip");
		return 0;
	}
}

sub GetSampleNumbers {
	my ( $self, $samplesref ) = @_;
	my $sql="SELECT sample_no,sample_id FROM ".$self->{data_prefix}."samples_".$self->{project_no};
	if (ref $samplesref eq 'ARRAY' and @$samplesref){
		$sql.=" WHERE sample_id IN (".join (",",('?') x @$samplesref).")" ;
	}
	my $query=$self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>$DBI::errstr});
	$query->execute(@$samplesref)  || $self->PegOut('DB error',{list=>$DBI::errstr});
	#	die2 ($sql,@$samplesref);
	my $results=$query->fetchall_arrayref;
	return  unless ref $results eq 'ARRAY' and @$results;
	return $results;
}

sub _InsertSamples {
	my ( $self, $samplesref ) = @_;
	unless (@$samplesref){
		die2 ("No samples!");
	}
	my $i=0;;
	my %samples=();
	if ($self->{new}){
#		die2 ("NEW");
		$self->CreateSamplesTable;
		$i = 1;
	}
	else {
		my $old_samplesref=$self->GetSampleNumbers();
	#	print "Content-Type: text/plain\n\n";
	#	print "Sorry, currently not possible.\n";
		foreach (@$old_samplesref){
			$samples{$_->[1]}=$_->[0];
			$i=$_->[0] if $_->[0]>$i;
		}
	#	print "<hr>SAMPLES ".join (", ",%samples)."<hr>";
		$i++;
	#	exit 0;
#		my $max_sample=$self->{dbh}->prepare( qq !SELECT MAX(sample_no) FROM ".$self->{data_prefix}."samples_!. $self->{project_no} ) || $self->PegOut('DB error',{list=>$DBI::errstr});
#		$max_sample->execute() || $self->PegOut('DB error',{list=>$DBI::errstr});
#		$i = $max_sample->fetchrow_arrayref->[0] + 1;
#		die2 ("OLD");
	}
	my $insert =
	  $self->{dbh}->prepare( "INSERT INTO ".$self->{data_prefix}."samples_"
		  . $self->{project_no}
		  . qq ! (sample_no,sample_id) VALUES (?,?)! )
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	my %new_samples;
	my %brief_samples=();
	my %samples_already_in_ab;
	my @sample_errors=();
	foreach (@$samplesref) {
#		die2("Sample $_ exists twice!") if $new_samples{$_};
		push @sample_errors,"Sample $_ exists twice!" if $new_samples{$_};
		unless ($samples{$_}){
			$new_samples{$_} = $i;
			$samples{$_} = $i;
			my $new=$_;
			my $modification=0;
			if ($new=~s/_\(GenomeWideSNP_\d+\)//){
				$modification=1;
			}
			if ($new=~s/\.brlmm-p.chp Codes//){
				$modification=1;
			}
			if ($new=~s/\s+/_/g){
				$modification=1;
			}
			if (length $new>20){
				$modification=1;
				$new=substr($new,0,20);
			}
			print "sample $_ was shortened to $_<br>\n" if $new ne $_;
	#		die2("Sample $new ($_) exists twice!") if $brief_samples{$new};
			push @sample_errors,"Sample $new ($_) exists twice!!" if $brief_samples{$new};
			$brief_samples{$new}=1;
			$insert->execute( $i++, $new ) || die2("Could not insert sample $_/$new\n$DBI::errstr");
		}
		else {
			$samples_already_in_ab{$_}=$samples{$_};
		}
	}
	if (@sample_errors) {
		$self->PegOut('Redundant samples',{list=>\@sample_errors});
	}
	$self->UseGenotypesFromDB({%samples_already_in_ab}) if scalar keys %samples_already_in_ab;
	$self->{samples} = \%samples;
}

sub UseGenotypesFromDB {
	my ( $self, $samplesref ) = @_;
	print "<strong>You are adding new genotypes for a sample already in the database.<br>This requires the re-use of the old data and might take some minutes...</strong><br>\n";
	my $sql =
	      "INSERT INTO ".$self->{data_prefix}."genotypesraw_"
	  . $self->{project_no}
	  .  qq ! (dbsnp_no,sample_no,genotype)
	  SELECT dbsnp_no,sample_no,genotype FROM !. $self->{data_prefix}."genotypes_". $self->{project_no}." WHERE sample_no=?";
	  my $copy=$self->{dbh}->prepare($sql)  || die2("Use of already stored data failed (1).",$DBI::errstr);
	$sql =
	    "DELETE FROM ".$self->{data_prefix}."genotypes_". $self->{project_no}." WHERE sample_no=?";
	my $delete=$self->{dbh}->prepare($sql)  || die2("Use of already stored data failed (2).",$DBI::errstr);
	foreach my $sample_id (keys %$samplesref){
		print "copying existing data for sample $sample_id # $samplesref->{$sample_id}<br>\n";
		$copy->execute($samplesref->{$sample_id}) || die ($!);
		print "done<br>deleting original data (copy will be merged with the new data)<br>\n";
		$delete->execute($samplesref->{$sample_id}) || die ($!);
		print "done\n";
	}
	print "The existing data was successfully copied and will be merged with the new data.<br>\n";
}


sub Commit {
	my $self = shift;
	foreach my $insert (keys %{$self->{rollback}->{inserts}}){
		my $sth=$self->{dbh}->prepare ("UPDATE $insert SET completed=true WHERE ".$self->{rollback}->{inserts}->{$insert}->[0].'=?')  || $self->PegOut('DB error',{list=>$DBI::errstr});
		$sth->execute($self->{rollback}->{inserts}->{$insert}->[1])  || $self->PegOut('DB error',{list=>$DBI::errstr});
		delete $self->{rollback}->{inserts};
	}
	$self->{dbh}->commit() || $self->PegOut('DB error',{list=>$DBI::errstr});
}

sub iCommit {
	my $self = shift;
	return unless ($self->{new});
	my $count=shift;
	if ($self->{last_commit}){
		my $ctime=time();
		my $delta=($self->{last_commit}?$ctime-$self->{last_commit}.' sec since last commit':'')  ;
		if ($delta>120){
			$self->{dbh}->commit() || $self->PegOut('DB error',{list=>$DBI::errstr});
			print "<small>[commit] $delta<br></small>\n";
			$self->{last_commit}=$ctime;
		}
	}
	else {
		$self->{last_commit}=time();
	}
#	if ($count=~/^\d+$/){
#		$self->{insertions}+=$count;
#		if ($self->{insertions}>250000){
#			my $ctime=time();
#			my $delta=($self->{last_commit}?$ctime-$self->{last_commit}.' sec since last commit':'')  ;
#			$self->{dbh}->commit() || $self->PegOut('DB error',{list=>$DBI::errstr});
#			print "<small>[commit] $delta<br></small>\n";
#			$self->{last_commit}=$ctime;
#			$self->{insertions}-=250000;
#		}
#	}
}


sub Rollback {
	my $self = shift;
	$self->{dbh}->rollback() || $self->PegOut('DB error',{list=>$DBI::errstr});
}

sub ReadSettings {
	my ( $self, $settings_file ) = @_;
	my %settings;
	open( IN, '<', $settings_file )
	  || die2("Could not open settings file $settings_file: $!\n");
	while (<IN>) {
		chomp;
		my ( $param, $value ) = split /:*\t/;
		$settings{$param} = $value;
	}
	close IN;
	$self->{settings} = \%settings;
}

sub InsertAnalysis {
	my ($self,$dataref)=@_;
	my ($project, $analysis_name, $allele_frequencies, $analysis_description,$homogeneity_required,$lower_limit,$exclusion_length,$limit)= @$dataref;
	my $date = sprintf ("%04d-%02d-%02d\n",((localtime)[5] +1900),((localtime)[4] +1),(localtime)[3]);
	my $analysis_no =
	  $self->{dbh}->prepare("SELECT nextval('".$self->{prefix}."sequence_analyses')")
	  || $self->PegOut('DB error',{list=>$DBI::errstr});
	$analysis_no->execute() || $self->PegOut('DB error',{list=>$DBI::errstr});
	$analysis_no = $analysis_no->fetchrow_arrayref->[0];
	my $sql="INSERT INTO ".$self->{prefix}."analyses
		(project_no, analysis_no, analysis_name, allele_frequencies, analysis_description, max_block_length, homogeneity_required, lower_limit, exclusion_length, date)
		VALUES (?,?,?,?,?,?,?,?,?,?)";
	my $insert=$self->{dbh}->prepare($sql) || $self->PegOut('DB error',{list=>[$sql,$DBI::errstr]});
	$limit=undef unless length $limit;
	$homogeneity_required=undef unless length $homogeneity_required;
	$lower_limit=undef unless length $lower_limit;
	$exclusion_length=undef unless length $exclusion_length;
	$insert->execute($project, $analysis_no, $analysis_name, $allele_frequencies, $analysis_description, $limit, $homogeneity_required, $lower_limit, $exclusion_length, $date)
		|| $self->PegOut("Error IAe2",{list=>["VALUES $project, $analysis_no, $analysis_name, $allele_frequencies, $analysis_description, $limit, $homogeneity_required, $lower_limit, $exclusion_length, $date",$sql,$DBI::errstr]});
	$self->{rollback}->{inserts}->{$self->{prefix}."analyses"}=['analysis_no',$analysis_no];
	return $analysis_no;
}

sub CreateSamplesAnalysisTable {
	my ($self,$analysis_no)=@_;
	my $id=$self->{project_no}.'v'.$analysis_no;
	my $tablename=$self->{data_prefix}."samples_".$id;
	my $sql=qq !
	CREATE TABLE $tablename (
		sample_no smallint  CONSTRAINT pk_!.$self->{species}."_samples_".$id.qq ! PRIMARY KEY
		CONSTRAINT fk_!.$self->{species}."_samples_".$id."_sample_no REFERENCES ".$self->{data_prefix}."samples_".$self->{project_no}.qq ! (sample_no),
		affected boolean CONSTRAINT nn_!.$self->{species}."_samples_".$id.qq !_affected NOT NULL
	);
	ALTER TABLE $tablename OWNER TO genetik;
	GRANT ALL ON TABLE $tablename TO postgres;
	GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE $tablename TO public!;
	$sql=~s/\n/ /sg;
	$self->{dbh}->do($sql) ||  die2($DBI::errstr,$sql);;
	$self->{rollback}->{tables}->{$tablename}=1;
	return $tablename;
}

sub BlockLength {
	my $self=shift;
	my $sql="SELECT gt.dbsnp_no, genotype FROM ".$self->{data_prefix}."genotypesraw_".$self->{project_no}.qq ! gt,
	$self->{markers_table}  pos WHERE gt.dbsnp_no=pos.dbsnp_no AND chromosome=? AND
	sample_no=? ORDER BY position!;
	my $q_genotypes=$self->{dbh}->prepare($sql) || die2 ($DBI::errstr);
	print $sql,"<br>\n";
	my $i_genotypes=$self->{dbh}->prepare(
	"INSERT INTO ".$self->{data_prefix}."genotypes_".$self->{project_no}.qq ! (sample_no, genotype, block_length, dbsnp_no) VALUES(?,?,?,?)!) || die2 ($DBI::errstr);
	foreach my $sample_no (sort {$a <=> $b} values %{$self->{samples}}){
		print "<b>Now analysing sample $sample_no...</b><br>\n";
		foreach my $chromosome (1..$self->{max_chr}){
			print "chromosome $chromosome...<br>\n";
#			$self->_BlockLength2DB($q_genotypes,$i_genotypes,$sample_no,$chromosome);
			$self->_BlockLength2DB_Fuzzy($q_genotypes,$i_genotypes,$sample_no,$chromosome);
		}
	}
}

sub BlockLengthVCF {
	my $self=shift;
	my $q_genotypes=$self->{dbh}->prepare(
	"SELECT position,genotype FROM ".$self->{data_prefix}."vcfgenotypesraw_".$self->{project_no}.qq !
	 WHERE chromosome=? AND sample_no=? ORDER BY position!) || die2 ($DBI::errstr);
	foreach my $sample_no (sort {$a <=> $b} values %{$self->{samples}}){
		print "<b>Now analysing sample $sample_no...</b><br>\n";
		foreach my $chromosome (1..$self->{max_chr}){
			my $i_genotypes=$self->{dbh}->prepare(
			"INSERT INTO ".$self->{data_prefix}."vcfgenotypes_".$self->{project_no}.qq ! (sample_no, genotype, block_length, position, chromosome) VALUES(?,?,?,?,$chromosome)!) || die2 ($DBI::errstr);
			print "chromosome $chromosome...<br>\n";
			$self->_BlockLength2DB_Fuzzy($q_genotypes,$i_genotypes,$sample_no,$chromosome);
		}
	}
}

sub _BlockLength2DB_Fuzzy {
	my ($self,$q_genotypes,$i_genotypes,$sample_no,$chromosome)=@_;
	print "<small>$chromosome: $sample_no query genotypes...</small>\n";
	my $starttime=time();
	$q_genotypes->execute($chromosome,$sample_no)  || die2 ($DBI::errstr);
	my $results=$q_genotypes->fetchall_arrayref;
	print "<small>finding homozygous blocks...</small>\n";
	my @blocklength=();
	my $pos=0;
	my $limit=$#$results;
	my $inserts=0;
	while ($pos <=$limit){
		if ($results->[$pos]->[1]==2) {
			$blocklength[$pos]=0;
			$inserts+=$i_genotypes->execute($sample_no,2,0,$results->[$pos]->[0]) || die2 ("BL2D2N / $self->{vcf} / $DBI::errstr");
			$pos++;
		}
		else {
			my $pos2=$pos;
			while (! _DetectBlockEnd($results,$pos,$pos2) && $pos2<=$limit){
				$pos2++;
			}
			my $blocklength=$pos2-$pos;
			$blocklength=32766 if $blocklength>32766;
			for my $pos3 ($pos..($pos2-1)){
				$inserts+=$i_genotypes->execute($sample_no,$results->[$pos3]->[1],$blocklength,$results->[$pos3]->[0]) || die2 ("BL2D2N / $self->{vcf} / $DBI::errstr");
			}
			$pos=$pos2;
		}
	}
	$self->iCommit($inserts);
	print "<small>$limit rows, ",(time()-$starttime)," seconds</small><br>\n";
}

sub _DetectBlockEnd {
	my $min=6;
	my ($results,$start,$pos)=@_;
	return 0 unless $results->[$pos]->[1]==2;
	return 1 unless $pos-$start>=$min;
	my $limit=$#$results-$pos;
	my $i=1;
	while ($i<=$min){
		if ($i<=$limit){
			return 1 if $results->[$pos+$i]->[1]==2;
		}
		$i++;
	}
	return 0;
}

sub BestBlockLengthLimit {
	my $self=shift;
	die2("Internal error, sub BestBlockLengthLimit")  unless $self->{project_no};
	my $query=$self->{dbh}->prepare ("SELECT marker_count FROM ".$self->{prefix}."projects WHERE project_no=?")  || die2 ($DBI::errstr);
	$query->execute($self->{project_no}) || die2 ($DBI::errstr);
	my $number=$query->fetchrow_arrayref;
	die2("Internal error, sub BestBlockLengthLimit N: $number") unless ref $number eq 'ARRAY';
	$number=$number->[0];
#	die ("N $number");
	return 80 unless $number>0;
	return 10000 if $number>5000000;
	return 2000 if $number>1500000;
	return 1000 if $number>800000;
	return 500 if $number>400000;
	return 250 if $number>200000;
	return 80 if $number>45000;
	return 15;
}

sub SetSpecies_Human {
	my $self=shift;
	$self->{prefix}='hm.';
	$self->{data_prefix}='hm_data.';
	$self->{markers_table}='markers';
	$self->{max_chr}=22;
	$self->{icon}='Human_small.png';
	$self->{icon_desc}='(c) <A href="http://www.nasa.gov/centers/ames/missions/archive/pioneer.html">L. Salzman Sagan, C. Sagan, F. Drake / NASA</A>';
	$self->{species_latin_name}='Homo sapiens';
	$self->{chr_length}={
		1 => 249250621,	2 => 243615958,	3 => 199505740,	4 => 191731959,	5 => 181034922,
		6 => 171115067,	7 => 159138663,	8 => 146364022,	9 => 141213431,	10 => 135534747,
		11 => 135006516,	12 => 133851895,	13 => 115169878,	14 => 107349540,	15 => 102531392,
		16 => 90354753,	17 => 81860266,	18 => 78077248,	19 => 63811651,	20 => 63741868,
		21 => 48129895,	22 => 51304566,
	};
}

sub SetSpecies_Dog {
	my $self=shift;
	$self->{prefix}='hm_dog.';
	$self->{data_prefix}='hm_dog_data.';
	$self->{markers_table}='hm_dog.markers';
	$self->{max_chr}=38;
	$self->{icon}='dog/Pictogram_Dog.png';
	$self->{icon_desc}='(c) <A href="http://commons.wikimedia.org/wiki/User:Mathieu19">Mathieu19</A>';
	$self->{species_latin_name}='Canis lupus';
	$self->{chr_length}={
		1 => 125616256,	2 => 88410189,	3 => 94715083,	4 => 91483860,	5 => 91976430,
		6 => 80642250,	7 => 83999179,	8 => 77315194,	9 => 64418924,	10 => 72488556,
		11 => 77416458,	12 => 75515492,	13 => 66182471,	14 => 63938239,	15 => 67211953,
		16 => 62570175,	17 => 67347617,	18 => 58872314,	19 => 56771304,	20 => 61280721,
		21 => 54024781,	22 => 64401119,	23 => 55389570,	24 => 50763139,	25 => 54563659,
		26 => 42029645,	27 => 48908698,	28 => 44191819,	29 => 44831629,	30 => 43206070,
		31 => 42263495,	32 => 41731424,	33 => 34424479,	34 => 45128234,	35 => 29542582,
		36 => 33840356,	37 => 33915115,	38 => 26897727,
	};
	# http://www.ensembl.org/Canis_familiaris/Location/Chromosome?r=38
}

sub SetSpecies_Rat {
	my $self=shift;
	$self->{prefix}='hm_rat.';
	$self->{data_prefix}='hm_rat_data.';
	$self->{markers_table}='hm_rat.markers';
	$self->{max_chr}=20;
	$self->{icon}='rat/rat.jpg';
	$self->{icon_desc}='(c) <A href="http://mkweb.bcgsc.ca/rat/images/raton3700/">Martin Krzywinsk</A>';
	$self->{species_latin_name}='Rattus norvegicus';
	$self->{chr_length}={
		1 => 267910886,	2 => 258207540,	3 => 171063335,	4 => 187126005,	5 => 173096209,
		6 => 147636619,	7 => 143002779,	8 => 129041809,	9 => 113440463,	10 => 110718848,
		11 => 87759784,	12 => 46782294,	13 => 111154910,	14 => 112194335,	15 => 109758846,
		16 => 90238779,	17 => 97296363,	18 => 87265094,	19 => 59218465,	20 => 55268282
	};
}

sub SetSpecies_Cow {
	my $self=shift;
	$self->{prefix}='hm_cow.';
	$self->{data_prefix}='hm_cow_data.';
	$self->{markers_table}='hm_cow.markers';
	$self->{max_chr}=29;
	$self->{icon}='cow/Cow_bw_06.png';
	$self->{icon_desc}='(c) <A href="http://commons.wikimedia.org/wiki/User:LadyofHats" >LadyofHats</A>';
	$self->{species_latin_name}='Bos taurus';
	$self->{chr_length}={
		1 => 161106243,	2 => 140800416,	3 => 127923604,	4 => 124454208,	5 => 125847759,
		6 => 122561022,	7 => 112078216,	8 => 116942821,	9 => 108145351,	10 => 106383598,
		11 => 110171769,	12 => 85358539,	13 => 84419198,	14 => 81345643,	15 => 84633453,
		16 => 77906053,	17 => 76506943,	18 => 66141439,	19 => 65312493,	20 => 75796353,
		21 => 69173390,	22 => 61848140,	23 => 53376148,	24 => 65020233,	25 => 44060403,
		26 => 51750746,	27 => 48749334,	28 => 46084206,	29 => 51998940,
	};
}

sub SetSpecies_Mouse {
	my $self=shift;
	$self->{prefix}='hm_mouse.';
	$self->{data_prefix}='hm_mouse_data.';
	$self->{markers_table}='hm_mouse.markers';
	$self->{max_chr}=19;
	$self->{icon}='mouse/Input-mouse.png';
	$self->{icon_desc}='(c) The <A href="http://tango.freedesktop.org/Tango_Desktop_Project">Tango! Desktop Project</A>';
	$self->{species_latin_name}='Mus musculus';
	$self->{chr_length}={
		1 => 197195432,	2 => 182548267,	3 => 159872112,	4 => 155630120,	5 => 152537259,
		6 => 150245815,	7 => 152524553,	8 => 132085098,	9 => 124135709,	10 => 130291745,
		11 => 122091587,	12 => 121257530,	13 => 120614378,	14 => 125194864,	15 => 103647385,
		16 => 98481019,	17 => 95272651,	18 => 90918714,	19 => 61342430,
	};
}

sub SetSpecies_Horse {
	my $self=shift;
	$self->{prefix}='hm_horse.';
	$self->{data_prefix}='hm_horse_data.';
	$self->{markers_table}='hm_horse.markers';
	$self->{max_chr}=31;
	$self->{icon}='horse/Horse_Rider_icon.png';
	$self->{icon_desc}='(c) <A href="http://commons.wikimedia.org/wiki/User:Wilfredor">Wilfredor</A>';
	$self->{species_latin_name}='Equus caballus';
	$self->{chr_length}={
		1 => 185838109,	2 => 120857687,	3 => 119479920,	4 => 108569075,	5 => 99680356,
		6 => 84719076,	7 => 98542428,	8 => 94057673,	9 => 83561422,	10 => 83980604,	11 => 61308211,
		12 => 33091231,	13 => 42578167,	14 => 93904894,	15 => 91571448,
		16 => 87365405,	17 => 80757907,	18 => 82527541,	19 => 59975221,	20 => 64166202,
		21 => 57723302,	22 => 49946797,	23 => 55726280,	24 => 46749900,	25 => 39536964,
		26 => 41866177,	27 => 39960074,	28 => 46177339,	29 => 33672925,	30 => 30062385,
		31 => 24984650,
	}
}

sub SetSpecies_Sheep {
	my $self=shift;
	$self->{prefix}='hm_sheep.';
	$self->{data_prefix}='hm_sheep_data.';
	$self->{markers_table}='hm_sheep.markers';
	$self->{max_chr}=26;
	$self->{icon}='sheep/Sheep_in_gray.png';
	$self->{icon_desc}='<A href="http://commons.wikimedia.org/wiki/File:Sheep_in_gray.svg">Micha&#322; Pecyna</A>';
	$self->{species_latin_name}='Ovis aries';
	$self->{chr_length}={
		1 => 299636549,	2 => 263108520,	3 => 242770439,	4 => 127201684,	5 => 116996412,
		6 => 129053557,	7 => 108923470,	8 => 97906876,	9 => 100790876,	10 => 94127923,
		11 => 66878309,	12 => 86402045,	13 => 89063022,	14 => 69302979,	15 => 90027688,
		16 => 77179534,	17 => 78614401,	18 => 72480257,	19 => 64803054,	20 => 55563675,
		21 => 55476369,	22 => 55746998,	23 => 66685354,	24 => 44850918,	25 => 48288072,
		26 => 50043613,
	};
}


sub StartOutput {
	my $self=shift if ref $_[0] eq 'HomozygosityMapper';;
	$self->{www_output_open}=1;
	my $title=shift;
	my $header_title=$title;
	$header_title=~s/<.*?>//g;
	my $options=shift;
	my $refresh='';
	if (ref $options->{refresh} eq 'ARRAY'){
		my $period=length $options->{refresh}->[1]?$options->{refresh}->[1]:5;
		$refresh=qq !<meta http-equiv="refresh" content="$period; URL=$options->{refresh}->[0]">!; #"
	}
	elsif ($options->{refresh}){
		$refresh=qq !<meta http-equiv="refresh" content="2; URL=$options->{refresh}">!;  #"
	}


	if ($options->{filename}){
		open (STDOUT,'>',$options->{filename}) || PegOut("Could not write to output file $options->{filename}",{list=>[$!]});
	#	open (STDERR,'>>',$options->{filename}) || PegOut("Could not write to output file $options->{filename}",{list=>[$!]});
	}
	else {
		print "Content-Type: text/html\n\n";
	}
	print <<EndHeader

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<HEAD>
<TITLE>$header_title</TITLE>
<link rel="shortcut icon" href="/HomozygosityMapper/HM_favicon.png" type="image/png">
<link rel="icon" href="/HomozygosityMapper/HM_favicon.png" type="image/png">
<link rel="stylesheet" href="/HomozygosityMapper/css.css" type="text/css">




$refresh
<STYLE type="text/css">
<!--
body {
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12pt;
}
td {
	font-family: Arial, Helvetica, sans-serif;
	font-size: 10pt;
	vertical-align: top;
}
.bold {
	font-weight: bold;
}
.red {
	color: red;
}
.blue {
	color: blue;
}
.green {
	color: green;
}
.darkgrey {
	color: #999999;
}
.yellow {
	color: yellow;
}
.violet {
	color: violet;
}
.grey {
	color: #CCCCCC;
}
.small {
	font-family: Arial, Helvetica, sans-serif;
	font-size: 8pt;
	vertical-align: top;
}
.redbg {
	background-color: red;
}
.bluebg {
	background-color: blue;
}
a {
	color: blue;
}
a:visited {
	color: blue;
}
h2 {
	font-family: Arial, Helvetica, sans-serif;
	font-size: 18pt;
}
h1 {
	font-family: Arial, Helvetica, sans-serif;
	font-size: 24pt;
}
.code {
	font-family: "Courier New", Courier, mono;
}
.input_field {
	width: 110pt;
}
EndHeader
;
	if ($options->{styles}){
		print ${$options->{styles}};
	}

	print qq !
	-->
	</STYLE>\n!;
	if ($options->{css}){
		print qq !<link href="$options->{css}" rel="stylesheet" type="text/css">\n!;
	}
	if ($options->{autocompletion}){
		my $all_users=$self->AllUsers();
		print '
	<link rel="stylesheet" href="https://code.jquery.com/ui/1.11.4/themes/smoothness/jquery-ui.css">
  <script src="https://code.jquery.com/jquery-1.10.2.js"></script>
  <script src="https://code.jquery.com/ui/1.11.4/jquery-ui.js"></script>
  <link rel="stylesheet" href="https://code.jquery.com/resources/demos/style.css">
  <script>
	$(function() {
    var users = ["';
    print join ('","', (map {$_->[0]} @$all_users));
    print '"
    ];
	$( "#newuser" ).autocomplete({
		source: users,
          minLength: 2,
    select: function(event, ui) {
        $("#newuser").val(ui.item.id)
    }
    });
  });
  </script>'
	}
	my $bodytext=$options->{body} || '';
	print "</head><body>";
	if ($options->{HomozygosityMapperSubtitle}){
		print qq*
	<table align="center" cellpadding="5" width="700">
		<TR>
			<TD width="120">
				<A HREF="/index.html">
					<IMG src="/HomozygosityMapper/HM_logo_small.png" alt="HomozgosityMapper pedigree" width="111" height="124" align="left" style="border: 0pt none;">
				</A>
			</TD>
			<TD width="460">
				<H1 align="center">HomozygosityMapper</H1>
				<H4 align="center" style="line-height: 35pt; margin:0"><i>$self->{species_latin_name}</i></H4>
				<H2 align="center" style="line-height: 15pt; margin:0" class="blue">$options->{HomozygosityMapperSubtitle}</H2>
			</TD>
			<TD width="120" style="vertical-align:middle">
				<A HREF="/HomozygosityMapper/$self->{species}">
					<IMG src="/HomozygosityMapper/$self->{icon}" alt='$self->{icon_desc}' align="right" style="border: 0pt none;">
				</A>
			</TD>
		</TR>
	</TABLE>\n*;
}
	elsif ($options->{StorageDBSubtitle}){
		print qq *
	<table border="0" align="center" cellpadding="5">
          <tr>
            <td><img src="/StorageDB/StorageDB_60px.png" alt="StorageDB" width="60" height="97"></td>
            <td><h1>StorageDB</h1><h2>$title</h2></td>
          </tr></table>\n*;

	}
	unless ($options->{no_heading}){
		print "<H2>$title</H2>\n" unless $options->{StorageDBSubtitle};
	}
}


sub PegOut {
	# HTML based variant of die
	my $self=shift;
	my $data=pop @_ if ref $_[-1] eq 'HASH'; # take hash ref out of @_
	open (OUT2,'>>','/tmp/hm_problems.txt') || die ($!);
#	print OUT Dumper ($self->{rollback}),"\n";
	foreach my $insert (keys %{$self->{rollback}->{inserts}}){
		print OUT2 "I $insert\n";
		my $sth=$self->{dbh}->prepare ("DELETE FROM $insert WHERE ".$self->{rollback}->{inserts}->{$insert}->[0].'=?')  ;
		print OUT2 "DELETE FROM $insert WHERE ".$self->{rollback}->{inserts}->{$insert}->[0]."=?\n";
		$sth->execute($self->{rollback}->{inserts}->{$insert}->[1]) ;
		delete $self->{rollback}->{inserts};
	}

	foreach my $table (keys %{$self->{rollback}->{tables}}){
		print OUT2 "T $table\n";
		my $sth=$self->{dbh}->do("DROP TABLE $table")  ;
		print OUT2 "DROP TABLE $table\n";
		delete $self->{rollback}->{tables}->{$table};
	}
	if ($self and $self->{dbh}){
		$self->{dbh}->commit || print OUT "Could not commit: DBI::errstr\n";
	}
	print OUT2 "OK\n";
	close OUT2;
	my $title=shift || ''; # when there's something left, it must be a title
	my @data=@_;
	unless ($self->{www_output_open}){
	# calls StartOutput when it was not called before
		unless ($self=~/Homozygosity/){
			StartOutput($title,{'no_heading'=>1});
		}
		else {
			$self->StartOutput($title,{'no_heading'=>1});
		}
	}
	print qq !<h2 class="red">$title</h2>\n! if $title;
	if (ref $data->{list} eq 'ARRAY'){
		if (@{$data->{list}}) {
			print "<ul>\n";
			foreach my $line (@{$data->{list}}){
				print "<li>$line</li>\n";
			}
			print "</ul>\n";
		}
	}
	elsif ($data->{list}){
		print "<li>$data->{list}</li>\n";

	}
	if (ref $data->{text} eq 'ARRAY' and @{$data->{text}}){
		print join ("<br>",
			map {
				s /\n/<br>/g;
				s/\t/ /g;
			$_ }
		@{$data->{text}});
	}
	if (@data){
		print join ("<br>",
			map {
				s /\n/<br>/g;
				s/\t/ /g;
			$_ }  @data);
	}
	EndOutput();
}

sub DefineExclusionLength {
	my ($self,$markers)=@_;
	return 20 if   $markers <  30000;
	return 250 if  $markers <  60000;
	return 1000 if $markers < 150000;
	return 2000 if $markers < 350000;
	return 4000 if $markers;
}


sub EndOutput {
	print "</BODY></HTML>\n";
	close STDOUT;
	exit 0;
}


return 1;