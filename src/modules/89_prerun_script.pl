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
my %config_wine = ();

&main;
sub main {
	my $config_file = $ARGV[0];
	my @args = ();

	my %config = %{read_config($config_file)};
	if ($opt_import) {
		%config = merge_hash_tables(read_config($opt_import), \%config);
	}

	setup_shell_env(\%config);

	if ($config{Wine}) {
		%config_wine = %{$config{Wine}};
		popu_wine_config(\%config_wine);
		setup_wine_env();
	}

	if ($config{Base}{PreRunScript}) {
		exec($config{Base}{PreRunScript});
	}
}


