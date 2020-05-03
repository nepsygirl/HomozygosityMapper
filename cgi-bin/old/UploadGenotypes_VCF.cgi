#!/usr/bin/perl

$|=1;
use strict;
use CGI qw(:standard); 
use CGI::Carp ('fatalsToBrowser');
use File::Basename;

my $tmpdir=($^O=~/win32/i?'t:/www':'/tmp');
my $htmltmpdir='/temp/';
$CGITempFile::TMPDIRECTORY=$tmpdir;
use lib '/www/lib/';
use HomozygosityMapperVCF;
my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});

my $user_id=$HM->Authenticate;

$HM->PegOut("Sorry, exclusion of columns has not yet been implemented. :-(") if $FORM{skip_columns};

my $filename="HM_temp_".time()."_".int(rand(100000));
$FORM{html_output}=$filename.'.html';
$FORM{"user_login"}=$user_id ;

if (length $FORM{project_name} && $FORM{project_no}){
	$HM->PegOut("Please either select an existing project or enter a new one.");
}
elsif (length $FORM{project_name}==0 && ! $FORM{project_no}){
	$HM->PegOut("Please select an existing project or enter a new one.");
}
elsif ($FORM{project_name}){
	$HM->QueryProject($FORM{project_name});
	if ($HM->{project_no}){
		$HM->PegOut("The project name is already in use. Please use a new one.");
	}
}
		
my @errors;
foreach my $param (qw/chip_no user_login/){
	push @errors,$param.' not set!' unless $FORM{$param};
}
foreach (keys %FORM){
	if ($_ eq 'filename'){
		my $fn=$FORM{$_};
		$fn=~s /.*\\//s; # für IE
		$fn=~s /.*\///s; # für IE
		push @errors,"Equality sign (=) not allowed in the filename ('$fn')" if  $fn=~/=/;
		push @errors,"Spaces are not allowed in the filename ('$fn')" if  $fn=~/ /;
		push @errors,"Only alphanumeric (letters, digits, _) characters are allowed in the filename ('$fn')" unless $fn=~/^[A-Z0-9a-z_.]+$/;
	}
	else {
		push @errors,"Spaces are not allowed in  $_ / $FORM{$_}" if  / / || $FORM{$_}=~/ /;
		push @errors,"Equality sign (=) not allowed in $_ / $FORM{$_}" if /=/ || $FORM{$_}=~/=/;
		push @errors,"Only alphanumeric (letters, digits, _) characters are allowed: $_ / $FORM{$_}" if $FORM{$_} && $FORM{$_}!~/^[A-Z0-9a-z_.]+$/;
	}
}
$HM->PegOut("Genotypes could not be uploaded:",{list=>\@errors}) if @errors;

my $fh = $cgi->upload('filename');
unless ($fh){
	$HM->PegOut("File could not be read.");
};

unless ($HM->CheckUser($FORM{user_login})){
	$HM->PegOut("$FORM{user_login}, please register first!");
}
$HM->{dbh}->disconnect();
my $html_target=$htmltmpdir.$FORM{html_output};

$HM->StartOutput("Genotypes are written to DB",{refresh=>[$html_target,5],
	'HomozygosityMapperSubtitle'=>'Genotypes are written to DB',
	'no_heading'=>1});

my @tempfiles=keys %{$cgi->{".tmpfiles"}};

if ($FORM{filename}=~/\.gz$/i){
	$FORM{compression}='gz';
}
elsif ($FORM{filename}=~/\.zip$/i){
	$FORM{compression}='zip';
}
$FORM{filename} = ${$cgi->{".tmpfiles"}->{$tempfiles[0]}->{name}}; 

$HM->PegOut("$FORM{filename} is not a valid file name (filehandle $fh)!") unless -e $FORM{filename};



print qq!Your genotypes are written to the database...\n!; #'
print qq!<h3 class="red">DON'T TRY TO RELOAD THIS PAGE, USE THE HYPERLINK BELOW INSTEAD</h3>\n!; #'
print '<hr>',$FORM{filename},'<hr>';
print qq!<A HREF="$html_target">see status</A>\n!;
print "</body></html>\n\n";
close (STDOUT);
close (STDIN);
undef $HM;
if ($^O=~/win32/i){
	exec ("c:/bin/perl/bin/perl d:/www/cgi-bin/HM/genotypes2db_VCF.pl ".join (" ",map {"$_=$FORM{$_}"} keys %FORM));
}
else {
	my $file='/tmp/deleteme'.int(rand(1000000)).'txt';
	exec ("/usr/bin/perl /www/cgi-bin/HM/genotypes2db_VCF.pl ".join (" ",map {"$_=$FORM{$_}"} keys %FORM). "> $file");
}
#$HM->EndOutput();
exit 0;