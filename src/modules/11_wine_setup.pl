#!%PERL%
use warnings;
use strict;

use Gamesetup::Base;
use Gamesetup::Wine;
use Getopt::Long qw(:config no_ignore_case);
use Digest::MD5::File qw(file_md5_hex);

my $opt_import;

GetOptions(
        'import|i=s'	=> \$opt_import,
);

my %config = ();
my %config_wine = ();

&main;
sub main {
	my $config_file = $ARGV[0];

	%config = %{read_config($config_file)};
	if ($opt_import) {
		%config = merge_hash_tables(read_config($opt_import), \%config);
	}

	setup_shell_env(\%config);

	if ($config{Wine}) {
		%config_wine = %{$config{Wine}};
	}
	else {
		exit 0;
	}

	popu_wine_config(\%config_wine);
	setup_wine_env();


	if (!$config_wine{Bin}) {
		$config_wine{Bin}="wine64";
	}
	system("wineboot");



	if ($config_wine{Registry_File}) {
		apply_reg($config_wine{Registry_File});
	}
}

sub apply_reg {
	my $file = shift(@_);

	my $md5 = file_md5_hex($file);
	my $wine_prefix = $ENV{WINEPREFIX};
	my $tracking_file = "$wine_prefix/.gs-appliedregs";

	my @applied_regs = file2array($tracking_file);

	if (!item_in_array($md5, @applied_regs)) {
		system('regedit', $file);
		my @new_applied;
		if (@applied_regs) {
			@new_applied = (@applied_regs, $md5);
		}
		else {
			@new_applied = ($md5);
		}
		array2file($tracking_file, @new_applied);
	}
}

sub item_in_array {
	my $s_item = shift(@_);
	my @array = @_;

	foreach my $item (@array) {
		if ($item eq $s_item) {
			return 1;
		}
	}
	return 0;
}
