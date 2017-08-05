#!%PERL%
use warnings;
use strict;

use File::Path;
use File::Copy;

use Gamesetup::Base;
use Getopt::Long qw(:config no_ignore_case);

my $opt_import;

GetOptions(
        'import|i=s'	=> \$opt_import,
);

my %config = ();
my %config_mod = ();

&main;
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

	if ($config{ModLoader}) {
		%config_mod = %{$config{ModLoader}};
	}
	else {
		exit 0;
	}

	if (!($config_mod{ModAvailDir} && $config_mod{ModLoadDir})) {
		warn "[Modloader] definition ModAvailDir, and ModLoadDir must be defined to load modules!\n";
		exit 1;
	}
	
	@list = @{get_mod_list()};
	@loaded = @{get_loaded_mods()};

	if (@list) {

		if ($config_mod{LoadMods} =~/^all$/i) {
			@load_mods = @list;
		}
		elsif ($config_mod{LoadMods} =~/^none$/i) {
			@load_mods = ();
		}
		elsif ($config_mod{LoadMods} =~/^asksingle$/i) {
			if (@loaded) {
				@load_mods = (prompt_for_mod(\@list, $loaded[0]));
			}
			else {
				@load_mods = (prompt_for_mod(\@list));
			}
		}
		else {
			@load_mods = @{prompt_for_mods(\@list, \@loaded)};
		}
	}
	if ($config_mod{WhiteList}) {
		my @wList = join("|", $config_mod{WhiteList});
		foreach my $file (@wList) {
			$whitelist{$file} = 1;
		}
	}

	if ($config_mod{load_script}) {
		load_mods(\@load_mods, \@loaded, \%whitelist, $config_mod{load_script});
	}
	else {
		load_mods(\@load_mods, \@loaded, \%whitelist);
	}
}

sub get_mod_list {
	my @mods;

	opendir(my $dh, $config_mod{ModAvailDir}) or return \@mods;
	while (readdir $dh) {
		if (
			$_ ne '.' && 
			$_ ne '..' && 
			$_=~/\S/
		) {
			my $mod = $_;
			push(@mods, $mod);
		}
	}
	@mods = sort(@mods);
	return \@mods;
}



sub get_loaded_mods {
	my @mods = ();

	opendir(my $dh, $config_mod{ModLoadDir}) or return \@mods;
	while (readdir $dh) {
		if (
			$_ ne '.' && 
			$_ ne '..' && 
			$_=~/\S/
		) {
			my $mod = $_;
			push(@mods, $mod);
		}
	}
	@mods = sort(@mods);
	return \@mods;
}

sub prompt_for_mods {
	my @list = @{$_[0]};
	my @loaded = @{$_[1]};
	my @output;

	my %loaded_hash;
	my @args;
	for my $mod (@loaded) {
		$loaded_hash{$mod} = 1;
	}

	foreach my $mod (@list) {
		if ($loaded_hash{$mod}) {
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
		"Select Modules to load:",
		"--checklist",  "--column",
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
	return \@output;
}

sub prompt_for_mod {
	my @list = @{$_[0]};
	my $loaded = $_[1];
	my @output;

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
	if (!$loaded) {
		push(@args, "TRUE", 'None');
	}
	else {
		push(@args, "FALSE", 'None');
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

sub load_mods {
	my @to_load = @{shift(@_)};
	my @loaded = @{shift(@_)};
	my %whitelist = %{shift(@_)};
	my $load_script = shift(@_);

	my %loaded_hash;
	my %to_load_hash;
	foreach my $mod (@loaded) {
		$loaded_hash{$mod} = 1;
	}

	foreach my $mod (@to_load) {
		$to_load_hash{$mod} = 1;
	}

	if ($load_script) {
		system($load_script, @to_load);
	}

	# add what's not there
	MOD: foreach my $mod (@to_load) {
		if ($whitelist{$mod}) {
			next MOD;
		}
		load_mod($mod);
	}
	MOD: foreach my $mod (@loaded) {
		if ($whitelist{$mod}) {
			next MOD;
		}
		if (!$to_load_hash{$mod}) {
			unload_mod($mod);
		}
	}
}

sub load_mod {
	my $mod = $_[0];

	if (!$config_mod{Copy}) {
		if (-l "$config_mod{ModLoadDir}/$mod") {
			if (
				readlink("$config_mod{ModLoadDir}/$mod") eq 
				"$config_mod{ModAvailDir}/$mod"
			) {
				return;
			}
			else {
				unload_mod($mod);
			}
		}
		elsif (-f "$config_mod{ModLoadDir}/$mod") {
			unlink("$config_mod{ModLoadDir}/$mod");
		}
		elsif (-d "$config_mod{ModLoadDir}/$mod" && "$config_mod{ModLoadDir}/$mod"=~/^\/\S/) {
			rmtree("$config_mod{ModLoadDir}/$mod");
		}
		symlink(
			"$config_mod{ModAvailDir}/$mod",
			"$config_mod{ModLoadDir}/$mod"
		) or warn "failed to create symlink: '$config_mod{ModLoadDir}/$mod' -> '$config_mod{ModAvailDir}/$mod': $!\n";
	}
	else {
		if ( -e "$config_mod{ModLoadDir}/$mod") {
			return;
		}
		if ($config_mod{ModSaveDir} &&  -e "$config_mod{ModSaveDir}/$mod") {
			move($config_mod{ModSaveDir}/$mod, "$config_mod{ModLoadDir}/$mod");
			return
		}
		if (
			! -e "$config_mod{ModLoadDir}/$mod"
		) {
			#system_w_output("rsync", "-truv", "$config_mod{ModAvailDir}/$mod", "$config_mod{ModLoadDir}/$mod");
			system("rsync", "-truv", "$config_mod{ModAvailDir}/$mod", "$config_mod{ModLoadDir}/");
		}
	}
}

sub unload_mod {
	my $mod = $_[0];
	if ($config_mod{ModSaveDir}) {
		move("$config_mod{ModLoadDir}/$mod", "$config_mod{ModSaveDir}/$mod") or warn "Failed to move '$config_mod{ModLoadDir}/$mod': $!\n";
	}
	else {
		if ( -d "$config_mod{ModLoadDir}/$mod") {
			if ($config_mod{ModLoadDir}=~/^\/\w/) {
				rmtree("$config_mod{ModLoadDir}/$mod") or warn "Failed to remove '$config_mod{ModLoadDir}/$mod': $!\n";
			}
		}
		else {
			unlink("$config_mod{ModLoadDir}/$mod") or warn "Failed to unlink '$config_mod{ModLoadDir}/$mod': $!\n";
		}
	}
}
