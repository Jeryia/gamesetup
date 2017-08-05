#!%PERL%
use warnings;
use strict;

use Gamesetup::Base;
use Getopt::Long qw(:config no_ignore_case);

my $opt_import;

GetOptions(
        'import|i=s'	=> \$opt_import,
);

my %config = ();

&main;
sub main {
	my $config_file = $ARGV[0];

	%config = %{read_config($config_file)};
	if ($opt_import) {
		%config = merge_hash_tables(read_config($opt_import), \%config);
	}
	my @args = ();

	setup_shell_env(\%config);

	if (!$config{Base}{Deps}) {
		exit 0;
	}

	system('gamsetup',
		$config{Base}{Deps},
		'--import', $config_file,
	);
}
