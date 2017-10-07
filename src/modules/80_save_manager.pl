#!%PERL%
use warnings;
use strict;

use File::Copy;

use Gamesetup::Base;
use Getopt::Long qw(:config no_ignore_case);

my $opt_import;
my $opt_save_name;

GetOptions(
        'import|i=s'	=> \$opt_import,
        'save_name=s'	=> \$opt_save_name,
);

my %config = ();
my %config_sav = ();

&main;
exit 0;
sub main {
	my $config_file = $ARGV[0];
	my @list;
	my @loaded;
	my %whitelist;

	my @load_mods;
	%config = %{read_config($config_file)};
	if ($opt_import) {
		%config = merge_hash_tables(read_config($opt_import), \%config);
	}

	setup_shell_env(\%config);

	if ($config{SaveManager}) {
		%config_sav = %{$config{SaveManager}};
	}
	else {
		exit 0;
	}

	if (!($config_sav{SaveDir} && $config_sav{SaveStorage})) {
		warn "[SaveManager] definition: SaveDir, and SaveStorage must be defined to load modules!\n";
		exit 1;
	}

	$config_sav{SaveStorage}=~s/\/$//g;
	system('mkdir', '-p', $config_sav{SaveStorage});
	my $current_save = get_loaded_save();
	my @saves = get_save_list();

	if (!$current_save or !@saves) {
		new_save($opt_save_name);
	}
	if ($opt_save_name) {
		$current_save = $opt_save_name;
	}
	else {
		$current_save = select_save(\@saves, $current_save);
	}
	if ($current_save eq 'New Save' or !item_in_array($current_save,@saves)) {
		new_save($opt_save_name);
	}
	else {
		set_save($current_save);
	}
}

sub get_save_list {
	my @saves;

	opendir(my $dh, $config_sav{SaveStorage}) or return \@saves;
	while (readdir $dh) {
		if (
			$_ ne '.' && 
			$_ ne '..' && 
			$_=~/\S/
		) {
			my $save = $_;
			push(@saves, $save);
		}
	}
	@saves = sort(@saves);
	return @saves;
}

sub new_save {
	my $name;
	if (@_ and $_[0]) {
		$name = shift(@_);
	}
	else {
		$name = prompt_sa_gui('Please select a name for your savegame.');
	}
	while($name=~/\//) {
		$name = prompt_sa_gui("Savegame name cannot contain any /'s.\nPlease select a name for your savegame.");
	}

	if (! -l $config_sav{SaveDir} and ( -d $config_sav{SaveDir} or -f $config_sav{SaveDir})) {
		move($config_sav{SaveDir}, "$config_sav{SaveStorage}/$name");
	}
	else {
		mkdir("$config_sav{SaveStorage}/$name");
	}
	set_save($name);
}

sub set_save {
	my ($name) = @_;
	if ( -e $config_sav{SaveDir}) {
		unlink($config_sav{SaveDir}) or die "Failed to remove '$config_sav{SaveDir}': $!\n";
	}
	symlink("$config_sav{SaveStorage}/$name", $config_sav{SaveDir}) or die "Failed to create link '$config_sav{SaveDir}': $!\n";
}

sub get_loaded_save {
	if ( ! -l "$config_sav{SaveDir}") {
		return;
	}
	my $cur_save = readlink($config_sav{SaveDir}) or die "failed to read link '$config_sav{SaveDir}': $!\n";

	$cur_save=~s/^\Q$config_sav{SaveStorage}\E//g;
	return $cur_save;
}

sub select_save {
	my @list = @{$_[0]};
	my $loaded = $_[1];
	my @output;

	push(@list, 'New Save');
	my %loaded_hash;
	my @args;
	foreach my $mod (@list) {
		if ($mod eq $loaded) {
			push(@args, "TRUE", $mod);
		}
		else {
			push(@args, "FALSE", $mod);
		}
	}
	my ($ret, $output_ptr) = system_w_stdout(
		"zenity",
		"--list",
		"--width=600",
		"--height=400",
		"--text",
		"Select a Module to load:",
		"--radiolist",  "--column",
		"Pick",
		"--column",
		"options",
		"--separator='\n'",
		@args
	);

	if ($ret != 0) {
		exit $ret;
	}

	@output = @{$output_ptr};
	foreach my $line (@output) {
		$line=~s/\n//;
		$line=~s/'$//;
		$line=~s/^'//;
	}
	if ($output[0] eq 'None') {
		return;
	}
	return $output[0];
}

## prompt_sa_gui
# Short answer prompt
# INPUT1: question
# OUTPUT: answer given (boolean)
sub prompt_sa_gui {
	my $question = shift(@_);

	my @output;
	while (!@output) {
		my ($ret, $output_ptr) = system_w_stdout(
			"zenity",
			"--entry",
			"--text",
			$question,
		);
		@output = @{$output_ptr};
	}
	foreach my $line (@output) {
		$line=~s/\s$//;
	}
	return $output[0];	
}

sub item_in_array {
	my $find_item = shift(@_);
	my @array = @_;

	foreach my $item (@array) {
		if ($item eq $find_item) {
			return 1;
		}
	}
	return 0;
}
