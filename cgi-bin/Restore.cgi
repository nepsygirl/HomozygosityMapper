#!/usr/bin/perl

$|=1;
use strict;
use CGI qw(:standard);
use CGI::Carp ('fatalsToBrowser');
use File::Basename;

my $tmpdir='/tmp/';
my $htmltmpdir='/temp/';
$CGITempFile::TMPDIRECTORY=$tmpdir;
use lib '/www/lib/';
use HomozygosityMapper;
my $cgi=new CGI;
my %FORM=$cgi->Vars();
my $HM=new HomozygosityMapper($FORM{species});
unless ($FORM{project_no}){
	$HM->PegOut("Please select an existing project that is owned by you.");
}
my $unique_id=$FORM{unique_id} || 0;
my $user_id=$HM->Authenticate;
unless ($user_id){
	$HM->PegOut("Please log in.");
}
my $dbh=$HM->{dbh};
my $q=$dbh->prepare ("SELECT project_name, vcf_build FROM ".$HM->{prefix}."projects
		WHERE archived IS NOT NULL AND project_no=? AND user_login=? ") || die2($DBI::errstr);
$q->execute ($FORM{project_no},$user_id) || die2($DBI::errstr);;
my $results=$q->fetchrow_arrayref || $HM->PegOut ("No project #".$FORM{project_no}." restorable for user '$user_id'") ;
$HM->{dbh}->disconnect();

@FORM{qw !project_name vcfbuild!}=@$results;
my $filename="HM_temp_".time()."_".int(rand(100000));
$FORM{html_output}=$filename.'.html';
$FORM{target_folder}=$filename;
$FORM{"user_login"}=$user_id ;
my $html_target=$htmltmpdir.$FORM{html_output};
$HM->StartOutput("Restoration of $FORM{project_name}...",{refresh=>[$html_target,10],
	'HomozygosityMapperSubtitle'=>"Restoration of $FORM{project_name}",
	'no_heading'=>1});



my $fh = $cgi->upload('filename');
unless ($fh){
	$HM->PegOut("File could not be read.");
};
$FORM{compression}='zip';
unless ($FORM{filename}=~/\.zip$/i){
	$HM->PegOut("Archive $FORM{filename} must be ZIPped.");
}




my @tempfiles=keys %{$cgi->{".tmpfiles"}};

if ($FORM{filename}=~/\.gz$/i){
	$FORM{compression}='gz';
}

$FORM{filename} = ${$cgi->{".tmpfiles"}->{$tempfiles[0]}->{name}};

$HM->PegOut("$FORM{filename} is not a valid file name (filehandle $fh)!") unless -e $FORM{filename};


my $file='/tmp/deleteme'.int(rand(1000000)).'txt';
print qq !Your genotypes are written to the database...\n!; #'
print qq !<h3 class="red">DON'T TRY TO RELOAD THIS PAGE, USE THE HYPERLINK BELOW INSTEAD</h3>\n!; #'
# print "<pre>","/usr/bin/perl /www/HomozygosityMapper/cgi-bin/restore.pl ".join (" ",map {"$_=$FORM{$_}"} keys %FORM). "> $file","</pre>";

print qq !<A HREF="$html_target">see status</A>\n!;
print "</body></html>\n\n";
close (STDOUT);
close (STDIN);
undef $HM;

exec ("/usr/bin/perl /www/HomozygosityMapper/cgi-bin/restore.pl ".join (" ",map {"$_=$FORM{$_}"} keys %FORM). "> $file") || die ($!);

#$HM->EndOutput();
exit 0;