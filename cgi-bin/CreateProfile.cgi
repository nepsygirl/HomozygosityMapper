#!/usr/bin/perl

$|=1;
use strict;
use HTML::Entities;
use CGI qw(:standard);
use CGI::Cookie;
use CGI::Carp ('fatalsToBrowser');
use utf8;
use Encode;
use lib '/www/lib/';
use HomozygosityMapper;

my $cgi=new CGI;
my $hm=new HomozygosityMapper;

my %FORM=$cgi->Vars();
my @fields=qw/user_login user_password user_name organisation user_email/;
my @errors;

push @errors, qq !Only alphanumeric (letters, digits, _) characters are allowed in the login: $FORM{user_login}! if  $FORM{user_login}=~/\W+/;


foreach my $field (@fields){
	push @errors,"$field is not set!" unless $FORM{$field};
	$FORM{$field} = encode( "UTF-8", $FORM{$field} );
}

if (@errors){
	$hm->die2("Some data is missing:",@errors);
}

my $q_user=$hm->{dbh}->prepare("SELECT user_login FROM hm.users WHERE UPPER(user_login)=?")
	|| $hm->PegOut($DBI::errstr);
$q_user->execute(uc $FORM{user_login}) || $hm->PegOut($DBI::errstr);
my $result=$q_user->fetchrow_arrayref;
if (ref $result eq 'ARRAY' and @$result and $result->[0]){
	$hm->PegOut("User name $result->[0] already in use - please choose another one.");
}

my $key=int(scalar time).'_'.int(rand(10**10));
my $insert=$hm->{dbh}->prepare("INSERT INTO hm.users (user_login, user_password, user_name,
	organisation, user_email) VALUES (?,?,?,?,?)") || $hm->PegOut($DBI::errstr);
$insert->execute(@FORM{qw/user_login user_password user_name organisation user_email/})
	|| $hm->PegOut($DBI::errstr);

my $cookie1 = new CGI::Cookie(-name=>'HomozygosityMapperAuth',-value=> encode_entities($FORM{user_login})."=".encode_entities($FORM{user_password}));
		print "Set-Cookie: $cookie1\n";
$hm->StartOutput("Homozygosity Mapper: user created",
	{no_heading=>1,
	'HomozygosityMapperSubtitle'=>'user created',
	});
print qq |<table border="0" align="center"><tr><td  align="center" style="font-size: 12pt"><p>Welcome <b>$FORM{user_login}</b></p>
<p>You have successfully created an account!</p>
<p>We have already logged you in, so you can start your personalised HomozygosityMapper right away.</p>
<p>Happy mapping...</p>
<br><br>
<h2 align="center"><A HREF="/HomozygosityMapper/index.html">Continue.</A></h3></td></tr></table>
|;
$hm->Commit();
$hm->EndOutput;
