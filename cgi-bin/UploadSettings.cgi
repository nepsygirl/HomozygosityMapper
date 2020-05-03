#!/usr/bin/perl
#!perl
use strict;
use CGI;

use HTML::Template;
use lib '/www/lib/';
use HomozygosityMapper;
my $file='/www/HomozygosityMapper/html/UploadGenotypes_template.html';
my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $user_id=$HM->Authenticate;

if ($user_id ~~[qw /sshirlee shirlee/]) {
	$HM->StartOutput ("Login",{no_heading=>1});
	print "You have to delete data first!";
	$HM->EndOutput();
	exit 0;
}

my $template = HTML::Template->new(filename => $file);




my $user_info='';
my $additional_info='';
my $access_restriction_info='';
unless ($user_id eq 'guest'){
	$user_info="logged in as user</td><td><i>".$user_id.qq ! </i><br><span class="small light">
	<A href="http://www.homozygositymapper.org/HM/login_form.cgi?species=$HM->{species}" target="_blank">
	login as a different user</a>&nbsp;&nbsp;&nbsp;&nbsp;(click RELOAD afterwards)
	</A></span> !; # "
	$template->param(access_restricted => 'checked')
}
else {
	$user_info=qq !</td><td>
	<span class="small light">
	<A href="http://www.homozygositymapper.org/HM/login_form.cgi?species=$HM->{species}" target="_blank">
	login</a>&nbsp;&nbsp;&nbsp;&nbsp;(click RELOAD afterwards)
	</A></span> !; # "
	$access_restriction_info=
		qq !<small class="red"><li>If this button is checked, a secret key for data access will be issued during the upload process. There is <b>absolutely no way</b> for you to retrieve your data without this key.</li>
		<li>If this is button is not checked, anyone will be able to view and delete your data.</li></small>!;   #'
	$additional_info=
		qq !<li class="red">Due to storage limitations, data created as guest will be deleted from time to time (we keep the data at least for two months).</li>
			<li class="red">Adding new genotypes to an existing private project is only possible with a user account.</li>
			<li class="red">You cannot use the homozygosity around a gene in GeneDistiller if your genotypes are private and you are not logged in.</li>!;   #'
}
$FORM{min_cov}=10 unless length $FORM{min_cov};
$template->param(min_cov => $FORM{min_cov}); 
$template->param(species => $FORM{species}) if $FORM{species};
$template->param(species_latin_name => $HM->{species_latin_name});
$template->param(icon => $HM->{icon});
$template->param(icon_desc => $HM->{icon_desc});
$template->param(user => $user_info);
$template->param(access_restriction_info => $access_restriction_info);
$template->param(additional_info => $additional_info);


my $chips='';
my $chipsref=$HM->AllChips;
foreach (@$chipsref){
	$chips.=qq ! <option value="$_->[0]">$_->[2]: $_->[1]</option> \n!;  # "
}
$template->param(chips => $chips);

# send the obligatory Content-Type and print the template output
print "Content-Type: text/html\n\n", $template->output;