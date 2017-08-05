#!%PERL%
use warnings;
use strict;

use Gamesetup::Base;
use Gamesetup::Wine;
use Getopt::Long qw(:config no_ignore_case);

my $opt_import;

GetOptions(
        'import|i=s'	=> \$opt_import,
);

my %config = ();
my %config_base = ();

&main;
sub main {
	my $config_file = $ARGV[0];

	%config = %{read_config($config_file)};
	if ($opt_import) {
		%config = merge_hash_tables(read_config($opt_import), \%config);
	}

	setup_shell_env(\%config);

	if ($config{Base}) {
		%config_base = %{$config{Base}};
	}
	else {
		exit 0;
	}
	if (!$config_base{Package} || !$config_base{Package_Dest}) {
		exit 0;
	}
	if ( -e $config_base{Package_Dest} && ! -d $config_base{Package_Dest}) {
		unlink($config_base{Package_Dest}) or die "remove $config_base{Package_Dest} failed: $!\n";
	}
	if (is_placed($config_base{Package}, $config_base{Package_Dest})) {
		exit 0;
	}

	system("mkdir", "-p", $config_base{Package_Dest});

	



	exec("tar", "-xzvf", $config_base{Package}, "-C", $config_base{Package_Dest});

}


## is_placed 
# check if tarball is already unpacked
# INPUT1: Tarball
# INPUT2: Destination
sub is_placed {
	my $tarball = shift(@_);
	my $dest = shift(@_);

	my %roots = ();
	my @output = ();
	my ($ret, $tmp) = system_w_stdout('timeout', '1', 'tar', '-tvf', $tarball);
	@output = @{$tmp};

	foreach my $line (@output) {
		# drwxrwxr-x grahamvh/grahamvh 0 2016-06-17 12:40 unpack/
		if ($line=~/\S+ \S+ \d+ \d\d\d\d-\d\d-\d\d \d\d:\d\d (.*)/) {
			my $path = $1;
			$roots{get_root_dir($path)} = 1;
		}
	}

	foreach my $root (keys %roots) {
		if (! -e "$dest/$root") {
			return 0;
		}
	}
	return 1;
}


## get_root_dir
# gets the root directory from a path
# INPUT1: path
# OUTPUT: directory
sub get_root_dir {
	my $path = shift(@_);

	my @tmp = split("/", $path);

	return $tmp[0];
}








