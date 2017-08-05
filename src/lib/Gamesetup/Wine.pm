#!/usr/bin/perl
package Gamesetup::Wine;
use warnings;
use strict;

use Gamesetup::Base;

our (@ISA, @EXPORT);
require Exporter;
@ISA = qw(Exporter);
@EXPORT= qw(popu_wine_config check_wine_os setup_wine_env wine_os_short setup_wine_os);

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
my %valid_os = %short_os_name;



my %config_wine = ();

sub popu_wine_config {
	%config_wine = %{$_[0]};
}

sub check_wine_os {
	my $desired_os = $_[0];

	if ( ! -e "$ENV{WINEPREFIX}/system.reg") {
		system("wineboot");
	}

	open(my $fh, "<", "$ENV{WINEPREFIX}/system.reg") or return 0;
	my @lines = <$fh>;
	close($fh);

	foreach my $line (@lines) {
		if ($line=~/$desired_os/) {
			return 1;
		}
	}
	return 0;
}

sub clean_wine_env {
	delete $ENV{WINEPREFIX};
	delete $ENV{WINEDLLOVERRIDES};
	delete $ENV{WINESERVER};
	delete $ENV{WINELOADER};
	delete $ENV{WINEDEBUG};
	delete $ENV{WINEDLLPATH};
	delete $ENV{WINEARCH};
	
}

sub setup_wine_env {
	clean_wine_env();
	

	# Validate requested environment is sane
	if ($config_wine{Prefix} && !($config_wine{Prefix} =~/^\//)) {
		die "Error! Setting [Wine] Prefix must be an absolute path!"
	}
	if ($config_wine{OS}) {
		if (!$valid_os{$config_wine{OS}}) {
			warn "Error! Invalid of specified at [Wine] OS='$config_wine{OS}'.\n";
			warn "Valid OS's: \n";
			foreach my $os (keys %valid_os) {
				warn "$os\n";
			}
			die;
		}
	};

	# Setup environment
	if ($config_wine{Prefix}) {
		$ENV{WINEPREFIX} = $config_wine{Prefix};
	}
	else {
		$ENV{WINEPREFIX}="$ENV{HOME}/.wine";
	}
	if ($config_wine{DllOverrides}) {
		$ENV{WINEDLLOVERRIDES} = $config_wine{DllOverrides};
	};
	if ($config_wine{Server}) {
		$ENV{WINESERVER} = $config_wine{Server};
	};
	if ($config_wine{Loader}) {
		$ENV{WINELOADER} = $config_wine{Loader};
	};
	if ($config_wine{Debug}) {
		$ENV{WINEDEBUG} = $config_wine{Debug};
	};
	if ($config_wine{DllPath}) {
		$ENV{WINEDLLPATH} = $config_wine{DllPath};
	};
	if ($config_wine{Arch}) {
		$ENV{WINEARCH} = $config_wine{Arch};
	};

	system("mkdir", "-p", baseDir($ENV{WINEPREFIX}));

	setup_wine_os();
	
}

sub wine_os_short {
	my $os = $_[0];

	return $short_os_name{$os};
}


sub setup_wine_os {
	if ($config_wine{OS}) {
		while (!check_wine_os($config_wine{OS})) {
        		system("zenity", "--info", "--text", "When the winecfg area comes up select '$config_wine{OS}', and hit enter", "--title", "notice") && exit 1;
	        	system_w_output("winecfg");
			# We wait a second, because wine seems to not immediately write out this file...
			my $sec = 0;
			WAIT: while (!check_wine_os($config_wine{OS})) {
				sleep 1;
				$sec++;
				if ($sec >= 10) {
					last WAIT;
				};
			}
		};
	};
};

sub baseDir {
	my $path = $_[0];

	my $output = '';
	my @tmp = split("/", $path);

	for (my $i=0; $i <= $#tmp; $i++) {
		$output .= "/$tmp[$i]";
	}
	return $output;
}

1;
