
print STDERR "Using compatibility macros/routines for Perl 5.004\n"
    if ($] < 5.0045);


use ExtUtils::MakeMaker;

my $root = "/blib/arch/auto/libmetaphone";


use Cwd;
my $pwd = fastcwd;

my $p = $pwd;

$pwd =~ s/(\w+)\/(\w+)$//;
$root = $pwd.$root;


WriteMakefile(
	'NAME'		=> 'Text::TransMetaphone::en_US',
	'VERSION_FROM'	=> '../../lib/Text/TransMetaphone/en_US.pm', # finds $VERSION
	'LIBS'		=> "-L$root -lmetaphone",
	'INC'		=> '-I../../include',
	'OBJECT'	=> '$(O_FILES)',
	'AUTHOR'	=> "Daniel Yacob <Yacob\@wMUsers.Com>",
	'ABSTRACT'	=> "Interface to the ActiveWorks Administration Libraries.",
	'TYPEMAPS'	=> [ "$p/../typemap" ]
);
