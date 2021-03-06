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


my $permissions=$HM->{dbh}->prepare("SELECT project_no, user_login, query_data, analyse_data
FROM ".$HM->{prefix}."projects_permissions WHERE project_no IN (".join (",",('?') x @projects).")") || die ($DBI::errstr);
$permissions->execute(@projects) || die ($DBI::errstr);
my %permissions;

my %users_with_access;
foreach (@{$permissions->fetchall_arrayref}){
	$permissions{$_->[0]}->{$_->[1]}=[$_->[2],$_->[3]];
	if (!$users_with_access{$_->[1]} and ($_->[2] or $_->[3])){
		$users_with_access{$_->[1]}=1;
	}
}
$HM->StartOutput("HomozygosityMapper: Set permissions", 	{'HomozygosityMapperSubtitle'=>'Set permissions',autocompletion=>1,
	'no_heading'=>1 });

my $next_user=0;
foreach (grep /^user/, keys %FORM) {
	my $number=$1 if $_=~/(\d+)/;
	$next_user=$number if ($number>$next_user);
}
$next_user++;
my @users_with_access=sort {$a cmp $b} keys %users_with_access;
$FORM{'user_'.$next_user}=$FORM{newuser} if $FORM{newuser};

my %altcolour=(-1=>'bgcolor="#E6E6E6"',1=>'');
print qq !
	<div id="popup" 
		style="border: 1px none rgb(0, 0, 0); overflow: visible; position: absolute; width: 300px; height: 115px; visibility: visible; z-index: 99; display: none; left: -28px; top: 708px;" 
		onMouseDown="firstcorner(this)">
	</div>
	<script src="/javascript/DisplayLayersPopups.js" type="text/javascript"></script>\n!;
	
print qq !<br>
	<form action="/HM/SelectPermissions.cgi" method="post" enctype="multipart/form-data">
		<input type="hidden" name="species" value="$HM->{species}">\n!; #"
for my $i (0..$next_user) {
	if ($FORM{'user_'.$i}) {
		print qq !<input type="hidden" name="user_!.$i.'" value="'.$FORM{'user_'.$i}.qq !">\n!;
		$users_with_access{$FORM{'user_'.$i}}=1;
	}
}
my @users_with_access=sort {$a cmp $b} keys %users_with_access;
print qq !<br><table cellpadding="4" cellspacing="0"  align="center">
<tr><td class="bold">add user</td><td><input id="newuser" name="newuser" size="20"></td><td><input type="submit" value="add"></td></tr>
</table></FORM>!;

print qq !<br><form action="/HM/SetPermissions.cgi" method="post" enctype="multipart/form-data">
<input type="hidden" name="species" value="$HM->{species}">\n!; #"
print qq !<br><table cellpadding="4" cellspacing="0"  align="center">
<tr><td class="bold" style="border-bottom-width: 1px;	border-bottom-style: solid;	border-bottom-color: #000000;">
<i>USER</i></td><td bgcolor="yellow" class="bold" rowspan="2">public<br>access</td>!;
my $colour=1;
foreach my $user (@users_with_access){
	print qq!<td colspan="2" $altcolour{$colour} class="bold" align="center">$user</td>\n!;
	$colour*=-1;
}
print qq!</tr><tr><td class="bold"><i>PROJECT</i></td>\n!;
my $colour=1;
foreach my $user (@users_with_access){
	print qq!<td $altcolour{$colour} align="center">query</td>
	<td $altcolour{$colour} align="center">analyse</td>\n!;
	$colour*=-1;
}
print qq!</tr>\n!;
my @cases=('query_data','analyse_data');
#my $ui=0;
foreach my $project (@$own_projects){
#	$ui++;
	my $checked=($project->[2]?'':'checked');
	my $name=$project->[0].'__publicaccess';
	my $link=qq !<A HREF="/HM/SelectChange.cgi?species=$HM->{species}&project_no=$project->[0]" TARGET="_blank">$project->[1]</A>!; #"
	
	print qq !<tr><td class="bold">$link</td><td bgcolor="yellow"><INPUT TYPE="checkbox" name ="$name" value="1" $checked></td>!; #"
	my $colour=1;
#	last if $ui>3 && $user_id eq 'dominik';
	foreach my $user (@users_with_access){
		if ($user eq $user_id){
			print qq!<td $altcolour{$colour} align="center">*</td><td $altcolour{$colour} align="center">*</td>\n!;
		}
		else {
			foreach my $i (0..1){
				my $checked=($permissions{$project->[0]}->{$user}->[$i]?'checked':'');
				my $name=$project->[0].'__'.$user.'__'.$cases[$i];
				print qq!<td $altcolour{$colour} align="center">
					<INPUT TYPE="checkbox" name ="$name" value="1" $checked onMouseOver="ShowPopup('$project->[1] / $user: $cases[$i]')" 
					onMouseOut="HidePopup('')" type="checkbox" >
				</TD>\n\n!;
			}
		}
		$colour*=-1;
	}
	print qq !</tr>!;
}
print qq !<tr><td colspan="!.(@users_with_access*2).qq!">
<INPUT type="submit" value="Set permissions"></td><td><A HREF="/documentation.html#grantaccess" TARGET="doc">help</A></td></tr></table></FORM>!;
$HM->EndOutput();