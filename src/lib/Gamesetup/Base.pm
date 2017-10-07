#/usr/bin/perl
package Gamesetup::Base;
use Config::IniFiles;
use warnings;
use strict;


our (@ISA, @EXPORT);
require Exporter;
@ISA = qw(Exporter);
@EXPORT= qw(merge_hash_tables read_config system_w_output system_w_stdout setup_shell_env array2file file2array);

my %blank_hash = ();


my %short_os_name;
$short_os_name{"Windows XP"} = "xp";
$short_os_name{"Windows Vista"} = "vista";
$short_os_name{"Windows 7"} = "7";
$short_os_name{"Windows 2003"} = "2003";
$short_os_name{"Windows 2008"} = "2008";
$short_os_name{"Windows 2008 R2"} = "2008rc2";
$short_os_name{"Windows 8"} = "8";
$short_os_name{"Windows 8.1"} = "8.1";
$short_os_name{"Windows 10"} = "10";

## merge_hash_tables 
# merges two hash tables
# INPUT1: hash table 1
# INPUT2: hash table 2 (this one overrides any duplicates)
# OUTPUT: merged hash table
sub merge_hash_tables {
	my %hash1 = %{shift(@_)};
	my %hash2 = %{shift(@_)};

	my %merge = %hash1;
	foreach my $key (keys %hash2) {
		if (ref($hash2{$key}) eq 'HASH' && ref($hash1{$key}) eq 'HASH') {
			$merge{$key} = merge_hash_tables($hash1{$key}, $hash2{$key});
		}
		elsif (ref($hash2{$key}) eq 'HASH') {
			my %tmp = %{$hash2{$key}};
			$merge{$key} = \%tmp;
		}
		elsif (ref($hash2{$key}) eq 'ARRAY') {
			my @tmp = @{$hash2{$key}};
			$merge{$key} = \@tmp;
		}
		else {
			$merge{$key} = $hash2{$key};
		}
	}

	return \%merge;
}

## _read_and_merge_configs
# Takes an initial config file and imports any files mentioned
# INPUT1: path to config file
# OUTPUT: hash of config files
sub _read_and_merge_configs {
	my $file = shift(@_);

	my %config;
	my @include_files;
	if (!tie(%config, 'Config::IniFiles', ( -file => $file))) {
		die "@Config::IniFiles::errors\n";
		return \%blank_hash;
	}
	foreach my $key1 (keys %config) {
		foreach my $key2 (keys %{$config{$key1}}) {
			$config{$key1}{$key2}=~s/^\s+//g;
			$config{$key1}{$key2}=~s/\s+$//g;
			$config{$key1}{$key2}=~s/^'//;
			$config{$key1}{$key2}=~s/'$//;
			$config{$key1}{$key2}=~s/^"//;
			$config{$key1}{$key2}=~s/"$//;

			$config{$key1}{$key2}=~s/\$HOME/$ENV{HOME}/g;
			$config{$key1}{$key2}=~s/\$USER/$ENV{USER}/g;
		}
	}

	if ($config{General}{Include}) {
		push(@include_files, @{expand_array($config{General}{Include})});
	}
	if ($config{Base}{Include}) {
		push(@include_files, @{expand_array($config{Base}{Include})});
	}

	foreach my $include_file (@include_files) {
		if (!($include_file=~/^\//)) {
			my $basedir = basedir($file);
			$include_file = "$basedir/$include_file";
		}
	
		if ($include_file) {
			my %config2 = %{_read_and_merge_configs($include_file)};
			%config = %{merge_hash_tables(\%config2, \%config)};
		}
	}
	return \%config;
}

## read_config
# Used to read ini stype config files
# INPUT1: location of config file
# OUTPUT: 2d hash of config file contents
sub read_config {
	my $file = $_[0];

	my %config;
	if (! -s $file ) {
		return \%blank_hash;
	}
	%config = %{_read_and_merge_configs($file)};


	if (!$config{Wine}{Prefix} && $config{Wine}{OS} && $short_os_name{$config{Wine}{OS}}) {
		$config{Wine}{Prefix} = "$ENV{HOME}/.wine_$short_os_name{$config{Wine}{OS}}";
	}


	my $loop_action = 1;
	my $max_loops = 100;
	my $loops = 0;
	Resolv: while ($loop_action > 0) {
		$loop_action = 0;
		foreach my $key1 (keys %config) {
			foreach my $key2 (keys %{$config{$key1}}) {
				if ( $config{$key1}{$key2}=~/\$(\w+).(\w+)/) {
					my $ref1 = $1;
					my $ref2 = $2;
					if ($config{$ref1}{$ref2}) {
						$config{$key1}{$key2}=~s/\$$ref1.$ref2/$config{$ref1}{$ref2}/g;
						$loop_action++;
					}
					else {
						warn "undefined variable found [$key1]  $key2='$config{$key1}{$key2}'\n";
						exit 1;
					}
				}
			}
		}
		$loops++;
		if ($loops >= $max_loops) {
			warn "maximum loops exceeded. Likely recursive config setting. Validate config.\n";
			last Resolv;
		}
	}
	return \%config;
};

sub system_w_output {
	my $cmd = shift(@_);
	my @args = @_;


	my @output;
	my $ret;
	pipe(READ,WRITE);

	my $pid = fork();
	if ($pid) {
		close(WRITE);
		@output = <READ>;
		waitpid($pid,0);
		$ret = $?;
		close(WRITE);
	}
	else {
		close(READ);
		open(STDOUT, ">&", \*WRITE) or die("PIPE Failure: $!\n");
		open(STDERR, ">&", \*WRITE) or die("PIPE Failure: $!\n");
		
		exec($cmd, @args);
		exit 1;
	}
	return ($ret, \@output);
}

## system_w_stdout 
# Run shell command and return stdout (safer than ``)
# INPUT1: command
# INPUT2-*: command arguments
# OUTPUT1: return code
# OUTPUT2: output
sub system_w_stdout {
	my $cmd = shift(@_);
	my @args = @_;


	my @output;
	my $ret;
	pipe(READ,WRITE);

	my $pid = fork();
	if ($pid) {
		close(WRITE);
		@output = <READ>;
		waitpid($pid,0);
		$ret = $?;
		close(WRITE);
	}
	else {
		close(READ);
		open(STDOUT, ">&", \*WRITE) or die("PIPE Failure: $!\n");
		
		exec($cmd, @args);
		exit 1;
	}
	return ($ret, \@output);
}

## setup_shell_env
# setup environment variables for the shell for determining library paths and executable paths
# INPUT1: config hash
sub setup_shell_env {
	my %config = %{shift(@_)};

	if ($config{Base}{PATH}) {
		if  ( ref $config{Base}{PATH} eq 'ARRAY') {
			my @paths = @{$config{Base}{PATH}};

			$ENV{PATH} = join(":", @paths) . ":$ENV{PATH}";
		}
		else {
			$ENV{PATH} = "$config{Base}{PATH}:$ENV{PATH}";
		}
	}
	if ($config{Base}{LD_LIBRARY_PATH}) {
		my $add_ld_libs = "";
		if  ( ref $config{Base}{LD_LIBRARY_PATH} eq 'ARRAY') {
			my @paths = @{$config{Base}{LD_LIBRARY_PATH}};

			$add_ld_libs = join(":", @paths) . ":$ENV{LD_LIBRARY_PATH}";
		}
		else {
			$add_ld_libs = "$config{Base}{LD_LIBRARY_PATH}";
		}
		if ($ENV{LD_LIBRARY_PATH}) {
			$ENV{LD_LIBRARY_PATH} = "$add_ld_libs:$ENV{LD_LIBRARY_PATH}";
		}
		else {
			$ENV{LD_LIBRARY_PATH} = "$add_ld_libs";
		}
	}
}

## basedir
# Get the directory containing the given file.
# INPUT1: path to file
# OUTPUT: path to it's containing directory
sub basedir {
	my $path = $_[0];
	$path=~s/\/$//g;
	my @dirs = split("/", $path);
	my $return = '';
	for (my $i = 0; $i < @dirs -1; $i++) {
		my $dir = $dirs[$i];
		$return .= "$dir/";
	};
	return $return;
};

## expand_array
# Take a string or array reference, and arraify any comma seperated lists in it.
# INPUT1: string or array ref
# OUTPUT: expanded array
sub expand_array {
	my $array = shift(@_);
	my @return = ();

	if (ref $array eq 'ARRAY') {
		foreach my $item (@{$array}) {
			push(@return, split(',', $item));
		}
	}
	else {
		push(@return, split(',', $array));
	}
	return \@return;
}

sub array2file {
	my $file = shift(@_);
	my @array = @_;

	open(my $fh, '>', $file) or return 0;
	print $fh join("\n", @array);
	close($fh);
}

sub file2array {
	my $file = shift(@_);

	my @array = ();
	open(my $fh, '<', $file) or return 0;
	@array = split("\n", <$fh>);
	close($fh);
	return @array;
}
1;
