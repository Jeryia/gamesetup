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
my %config_hy = ();

&main;
sub main {
	my $config_file = $ARGV[0];
	my @args = ();

	%config = %{read_config($config_file)};

	if ($opt_import) {
		%config = merge_hash_tables(read_config($opt_import), \%config);
	}
	setup_shell_env(\%config);

	if ($config{Hybridize}) {
		%config_hy = %{$config{Hybridize}};
	}
	else {
		exit 0;
	}

	if (!(
		$config_hy{Source} && 
		$config_hy{Dest}
	)) {
		warn "You need to define the [hybridize] stanzas 'Source', and 'Dest'!";
		exit 1;
	}
	if ($config_hy{Purge}) {
		push(@args, "--purge");
	}
	if ($config_hy{GreyList}) {
		push(@args, "-g");
		push(@args, $config_hy{GreyList});
	}
	if ($config_hy{CopyList}) {
		push(@args, "--copylist");
		push(@args, $config_hy{CopyList});
	}
	if ($config_hy{WhiteList}) {
		push(@args, "--copylist");
		push(@args, $config_hy{WhiteList});
	}
	if ($config_hy{ExcludeList}) {
		push(@args, "--excludelist");
		push(@args, $config_hy{ExcludeList});
	}
	if ($config_hy{NoModifyList}) {
		push(@args, "--nomodifylist");
		push(@args, $config_hy{NoModifyList});
	}
	push(@args, $config_hy{Source});
	push(@args, $config_hy{Dest});

	system("mkdir", "-p", "$config_hy{Dest}");
	system("/usr/bin/hybridize", @args);
}

