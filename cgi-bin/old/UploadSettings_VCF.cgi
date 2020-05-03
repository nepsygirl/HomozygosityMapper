#!/usr/bin/perl
#!perl
use strict;
use CGI;
use HTML::Template;
use lib '/www/lib/';
use HomozygosityMapperVCF;
my $file='/www/HomozygosityMapper/UploadGenotypesVCF_template.html';
my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
my $user_id=$HM->Authenticate;
my $template = HTML::Template->new(filename => $file);

my $user_info='';
my $additional_info='';
unless ($user_id eq 'guest'){
	$user_info="<i>".$user_id.qq ! </i><br><span class="small light">
	<A href="$HM->{species_dir}/login.html" target="_blank">
	login as a different user</a>&nbsp;&nbsp;&nbsp;&nbsp;(click RELOAD afterwards)
	</A></span> !;
	$template->param(access_restricted => 'checked')
}
else {
	$user_info=qq !<span class="red">not logged in&nbsp;&nbsp;&nbsp;<small><b>please read the restrictions below</b></small></span><br>
	<span class="small light">
	<A href="$HM->{species_dir}/login.html" target="_blank">
	login</a>&nbsp;&nbsp;&nbsp;&nbsp;(click RELOAD afterwards)
	</A></span> !;
	$additional_info=
		qq !<li class="red">If you create private data without being logged in, a secret key for data access will be issued during the upload process.</li>
			<li class="red">There is <b>absolutely no way</b> for you to retrieve your data without this key.</li>
			<li class="red">Due to storage limitations, data created as guest will be deleted from time to time (we keep the data at least for two months).</li>
			<li class="red">Adding new genotypes to an existing private project is only possible with a user account.</li>
			<li class="red">You cannot use the homozygosity around a gene in GeneDistiller if your genotypes are private and you are not logged in.</li>
			<li class="green">For easier access to your data and to share your data with collaborators, please consider <A HREF="http://www.homozygositymapper.org/CreateProfile.html">creating a user account</A>. It's absolutely free.</li> !;   #'
}

$template->param(species => $FORM{species}) if $FORM{species};
$template->param(species_latin_name => $HM->{species_latin_name});
$template->param(icon => $HM->{icon});
$template->param(icon_desc => $HM->{icon_desc});
$template->param(user => $user_info);
$template->param(additional_info => $additional_info);


my $chips='';
my $chipsref=$HM->AllChips;
foreach (@$chipsref){
	$chips.=qq ° <option value="$_->[0]">$_->[2]: $_->[1]</option> \n°;
}
$template->param(chips => $chips);

# send the obligatory Content-Type and print the template output
print "Content-Type: text/html\n\n", $template->output;