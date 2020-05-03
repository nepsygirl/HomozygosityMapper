#!/usr/bin/perl
$|=1;
use strict;
use lib '/www/lib/';
use HomozygosityMapper;
use CGI;
my @datafiles=();
my $cgi=new CGI;
my %FORM=$cgi->Vars();

my $tmpdir='/tmp/';
my $htmltmpdir='/temp/';

my $export_subfolder;
my $export_folder;

my $HM=new HomozygosityMapper($FORM{species});
$HM->PegOut("No project selected.") unless $FORM{project};
#die (join (",",%FORM));

my $dbh=$HM->{dbh};
my $unique_id=$FORM{unique_id} || 0;
my $user_id=$HM->Authenticate;
my ($project,$project_name)=();
my $own_projects=$HM->AllProjects($user_id,'own',$unique_id,'allow uncompleted');
my $vcf_project;

foreach (@$own_projects){
	next unless $_->[0]==$FORM{project};
	$project=$_->[0];
	$project_name=$_->[1];
	$vcf_project="(VCF, build $_->[4])" if $_->[4];
}


unless  ($project ){
	$HM->die2("You did not select anything to archive...");
}




unless ($FORM{confirmed}){
	$HM->StartOutput("HomozygosityMapper: Confirm archiving of your $FORM{species} data",{
	'HomozygosityMapperSubtitle'=>"Confirm archiving of your $FORM{species} data",
	'no_heading'=>1});
	print qq !<form action="/HM/Archive.cgi" method="post" enctype="multipart/form-data">
	<input type="hidden" name="species" value="$FORM{species}">
	<table cellpadding="10" width="800" align="center"><tr><td>\n!;

		print "Project: <B>$project_name</B>$vcf_project<br>\n";
		print qq !<INPUT type="hidden" name="project"  value="$project">\n!;


	print qq !<br><INPUT type="submit" value="Confirm archiving." name="confirmed" value="1">\n!;
	print qq !<input type="hidden" name="unique_id" value="$unique_id">\n! if $unique_id;
	
	print qq !</td></TR></table></form>!;
}
else {
		my $filename="HM_temp_".time()."_".int(rand(100000));
	$FORM{html_output}=$filename.'.html';
	my $html_target=$htmltmpdir.$FORM{html_output};
	$HM->StartOutput("HomozygosityMapper: archiving...",
	{refresh=>[$html_target,10],
	'HomozygosityMapperSubtitle'=>"archiving your $FORM{species} data...",
	'no_heading'=>1});
	print '<b class="red">NEVER press F5/reload - this will archive the data without providing access to the archive!</b><br>';
#	print "<pre>","/usr/bin/perl /www/HomozygosityMapper/cgi-bin/archive.pl ",
#	join (" ",map {"$_=$FORM{$_}"} keys %FORM) ,"</pre>\n";
	print "</body></html>\n\n";
	close (STDOUT);
	close (STDIN);
	undef $HM;
	my $cmd="/usr/bin/perl /www/HomozygosityMapper/cgi-bin/archive.pl >> /tmp/archive.log ".join (" ",map {"$_=$FORM{$_}"} keys %FORM);
	exec ($cmd) || die ($!);
	exit 0;
}

__END__
/usr/bin/perl /www/HomozygosityMapper/cgi-bin/archive.pl confirmed=Confirm archiving. project=20282 species= html_output=HM_temp_1464378304_80004.html

