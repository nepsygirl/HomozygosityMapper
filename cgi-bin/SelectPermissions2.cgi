#!/usr/bin/perl

use strict;
use CGI;

use lib '/www/lib/';
use HomozygosityMapper;
my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});


my $user_id=$HM->Authenticate;
$HM->PegOut("Please log in first.") if $user_id eq 'guest' or length $user_id<1;

my $own_projects=$HM->AllProjects($user_id,'own');
my @projects=map {$_->[0]} @$own_projects;
$HM->PegOut("You don't own any projects.") unless @projects;
my $all_users=$HM->AllUsers();
my @users=map {$_->[0]} @$all_users;

my $permissions=$HM->{dbh}->prepare("SELECT project_no, user_login, query_data, analyse_data
FROM ".$HM->{prefix}."projects_permissions WHERE project_no IN (".join (",",('?') x @projects).")") || die ($DBI::errstr);
$permissions->execute(@projects) || die ($DBI::errstr);
my %permissions;
foreach (@{$permissions->fetchall_arrayref}){
	$permissions{$_->[0]}->{$_->[1]}=[$_->[2],$_->[3]];
}
my @cases=('query_data','analyse_data');
my @printcases=('query','analyse');
$HM->StartOutput("HomozygosityMapper: Set permissions", 	{'HomozygosityMapperSubtitle'=>'Set permissions',
	'no_heading'=>1 });
print qq!<br>
<form action="/HM/SetPermissions.cgi" method="post" enctype="multipart/form-data">
<input type="hidden" name="species" value="$HM->{species}">\n!;
my %altcolour=(-1=>'bgcolor="#E6E6E6"',1=>'');
print qq!<br><table cellpadding="4" cellspacing="0"  align="center">
<tr>
<td><ul>!;
foreach my $project (@$own_projects){
	my $link='#'.$project->[0];
	print qq!<li><A HREF="$link">$project->[1]</A></li>\n!;
}
	
print qq!</ul></td><td><table cellpadding="4" cellspacing="0"  align="center"><tr>
<td colspan="4"><A HREF="/HM/SelectPermissions.cgi?species=!.$HM->{species}.qq!" class="bold">back to the old interface</A></td></tr>
<tr class="bold" ><td>project</td><td>user</td><td colspan="2">access</td></tr>\n!;

foreach my $project (@$own_projects){
	my $checked=($project->[2]?'':'checked');
	my $name=$project->[0].'__publicaccess';
		my $link=qq!<A HREF="/HM/SelectChange.cgi?species=$HM->{species}&project_no=$project->[0]" TARGET="_blank">$project->[1]</A>!;
	print qq!<tr bgcolor="yellow"><td class="bold">$link<A NAME="$project->[0]"></A></td><td>public access </td><td colspan="2"><INPUT TYPE="checkbox" name ="$name" value="1" $checked> </td></tr>!;
	my $colour=1;
	foreach my $user (@users){
		unless ($user eq $user_id){
			print qq!<tr $altcolour{$colour} ><td>$project->[1]</td><td>$user</td>\n!;	
			foreach my $i (0..1){
							
				my $checked=($permissions{$project->[0]}->{$user}->[$i]?'checked':'');
				my $name=$project->[0].'__'.$user.'__'.$cases[$i];
				print qq!<td>
					<INPUT TYPE="checkbox" name ="$name" value="1" $checked> $printcases[$i]
				</TD>\n\n!;
			}
			print "</tr>\n";
			$colour*=-1;
		}
	
	}
	print qq !<tr><td colspan="4"></td></tr>!;
	

}




print qq !</table></td></tr></table><INPUT type="submit" value="Set permissions"> <A HREF="/documentation.html#grantaccess" TARGET="doc">help</A></FORM>!;
$HM->EndOutput();