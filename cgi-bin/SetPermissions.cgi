#!/usr/bin/perl

use strict;
use CGI;
use lib '/www/lib/';
use HomozygosityMapper;
my $cgi=new CGI;

my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
delete $FORM{species};
my $user_id=$HM->Authenticate;
my $own_projects=$HM->AllProjects($user_id,'own');
my @projects=map {$_->[0]} @$own_projects;

#die (join (",",@projects)) if $FORM{species} eq 'dog';

my %projects;
@projects{@projects}=();

my %permissions;
# granular access
my $permissions=$HM->{dbh}->prepare(
	"SELECT project_no, user_login, query_data, analyse_data
	FROM ".$HM->{prefix}."projects_permissions WHERE project_no IN (".
	join (",",('?') x keys %projects).")")
	|| die ($DBI::errstr);
$permissions->execute(keys %projects) || die ($DBI::errstr);

my $sql="SELECT project_no, user_login, query_data, analyse_data
	FROM ".$HM->{prefix}."projects_permissions WHERE project_no IN (".
	join (",",('?') x keys %projects).")";
	
my @permissions2grant;
my @permissions2revoke;
my %permissions2change;
my %public_permissions2change;

foreach (@$own_projects){
	if ($_->[2] == $FORM{$_->[0].'__publicaccess'}){
		$public_permissions2change{$_->[0]}=int ($FORM{$_->[0].'__publicaccess'}-1)*-1;
	}
}

foreach (@{$permissions->fetchall_arrayref}){
	$permissions{$_->[0]}->{$_->[1]}=[$_->[2],$_->[3]];
	if ($_->[2] && !$FORM{$_->[0].'__'.$_->[1].'__query_data'}){
		$permissions2change{$_->[0]}->{$_->[1]}->[0]=0;
	}
	if ($_->[3] && !$FORM{$_->[0].'__'.$_->[1].'__analyse_data'}){
		$permissions2change{$_->[0]}->{$_->[1]}->[1]=0;
	}
}

foreach my $key (keys %FORM){
	my ($project,$user,$grant)=split /__/,$key;
	next if $user eq 'publicaccess';
	my $index=($grant eq 'query_data'?0:1);
	$HM->PegOut("Error",{list=>["You are not owner of this project!"]}) unless exists $projects{$project};
	unless ($permissions{$project} and $permissions{$project}->{$user} and $permissions{$project}->{$user}->[$index]){
		$permissions2change{$project}->{$user}->[$index]=1;
	}
}
my $update=$HM->{dbh}->prepare(
	"UPDATE ".$HM->{prefix}."projects_permissions SET query_data=?, analyse_data=?
	WHERE project_no=? AND user_login=?")
	|| die ($DBI::errstr);
my $insert=$HM->{dbh}->prepare(
	"INSERT INTO ".$HM->{prefix}."projects_permissions (query_data, 
	analyse_data, project_no, user_login) VALUES (?,?,?,?)")
	|| die ($DBI::errstr);
my $update_public=$HM->{dbh}->prepare(
	"UPDATE ".$HM->{prefix}."projects SET access_restricted=?
	WHERE project_no=? ")
	|| die ($DBI::errstr);
foreach my $project (keys %permissions2change){
	foreach my $user (keys %{$permissions2change{$project}}){
		for my $i (0..1){
			unless (defined $permissions2change{$project}->{$user}->[$i]){
				if ($permissions{$project} and $permissions{$project}->{$user}){
					$permissions2change{$project}->{$user}->[$i]=
						(defined $permissions{$project}->{$user}->[$i]?
						$permissions{$project}->{$user}->[$i]:
						0);
				}
				else {
					$permissions2change{$project}->{$user}->[$i]=0;
				}
			}
		}
		unless ($permissions{$project}->{$user}){
			$insert->execute(@{$permissions2change{$project}->{$user}},$project,$user) || die ($DBI::errstr);
		}
		else {
			$update->execute(@{$permissions2change{$project}->{$user}},$project,$user) || die ($DBI::errstr);
		}
	}
}
foreach my $project (keys %public_permissions2change){
	$update_public->execute($public_permissions2change{$project},$project) || die ($DBI::errstr);
}

$HM->Commit;
$HM->StartOutput("Permissions updated.",{refresh=>['/HM/SelectPermissions.cgi?species='.$HM->{species},2],
	'HomozygosityMapperSubtitle'=>'Permissions updated',
	'no_heading'=>1});
$HM->EndOutput();