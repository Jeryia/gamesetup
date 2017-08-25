#!/usr/bin/perl
use warnings;
use strict;

use Cwd;
use Test::Simple tests => 95;

use lib("./build/lib");
use Gamesetup::Base;
use Gamesetup::Wine;

$ENV{PERL5LIB}="./build/lib/";

my $CWD = getcwd();

main();
exit 0;

sub main {
	mkdir("$CWD/tmp/");

	# libraries
	lib_base_tests();
	lib_wine_tests();

	# modules
	wine_setup_tests();
	unpack_tests();
	hybridize_tests();
	modloader_tests();
	wine_deps_tests();
	prerun_script_tests();
	exec_tests();
}

sub lib_base_tests {
	print "\n\nStarting tests against Gamesetup::Base\n";

	
	my %hash1;
	my %hash2;
	$hash1{test1} = 1;
	$hash2{test2} = 1;
	my %config = %{merge_hash_tables(\%hash1, \%hash2)};
	
	ok($config{test1}, "merge_hash_tables: 1d hash1 merged") or die;
	ok($config{test2}, "merge_hash_tables: 1d hash2 merged") or die;

	%hash1 = ();
	%hash2 = ();
	$hash1{test1}{bob} = 1;
	$hash2{test1}{phil} = 1;
	%config = %{merge_hash_tables(\%hash1, \%hash2)};
	
	ok($config{test1}{bob}, "merge_hash_tables: 2d hash1 merged") or die;
	ok($config{test1}{phil}, "merge_hash_tables: 2d hash2 merged") or die;

	%config = %{read_config("build/tests/areas/lib_base/read_config_test.conf")};
	
	ok($config{Base}{BinDir} eq "/bin", "read_config: General config option") or die;

	ok($config{Base}{Ls} eq "/bin/ls", "read_config: variable substitution") or die;
	ok($config{Base}{MyHome} eq $ENV{HOME}, "read_config: USER HOME substitution '$config{Base}{MyHome}' vs '$ENV{HOME}'") or die;
	ok($config{Base}{MyUser} eq $ENV{USER}, "read_config: USER Name substitution '$config{Base}{MyUser}' vs '$ENV{USER}'") or die;



	%config = %{read_config("build/tests/areas/lib_base/read_import_config_test.conf")};
	ok($config{Base}{BinDir} eq "/bin", "read_config: Import General config option") or die;
	ok($config{Base}{Ls} eq "/bin/ls", "read_config: Import variable substitution") or die;
	ok($config{Base}{MyHome} eq $ENV{HOME}, "read_config: Import USER HOME substitution '$config{Base}{MyHome}' vs '$ENV{HOME}'") or die;
	ok($config{Base}{MyUser} eq $ENV{USER}, "read_config: Import USER Name substitution '$config{Base}{MyUser}' vs '$ENV{USER}'") or die;



	my ($ret, $output_ptr) = system_w_output("echo", "hi");
	my $output = join("",@{$output_ptr});
	ok($output eq "hi\n", "system_w_output: output test") or die;

}

sub lib_wine_tests {

	my %config;
	my %config_wine;
	print "\n\nStarting tests against Gamesetup::Wine\n";



	## check environment variables are set correctly
	%config = %{read_config("build/tests/areas/lib_wine/wine_env_test.conf")};
	%config_wine = %{$config{Wine}};
	popu_wine_config(\%config_wine);
	setup_wine_env();

	ok($ENV{WINEPREFIX} eq "$CWD/tmp/wine_env_test", "setup_wine_env: WINEPREFIX: '$ENV{WINEPREFIX}' ne '$CWD/tmp/wine_env_test'") or die;
	ok($ENV{WINEDLLOVERRIDES} eq "ddraw=n,b", "setup_wine_env: WINEDLLOVERRIDES") or die;
	ok($ENV{WINESERVER} eq "server", "setup_wine_env: WINESERVER") or die;
	ok($ENV{WINELOADER} eq "loader", "setup_wine_env: WINELOADER") or die;
	ok($ENV{WINEDEBUG} eq "debug", "setup_wine_env: WINEDEBUG") or die;
	ok($ENV{WINEARCH} eq "arch", "setup_wine_env: WINEARCH") or die;


	## check check_wine_os function
	$ENV{WINEPREFIX}="$CWD/build/tests/areas/lib_wine/wine_areas/xp";
	ok(check_wine_os("Windows XP"), "check_wine_os: positive validation") or die;
	ok(!check_wine_os("Windows 7"), "check_wine_os: negative validation") or die;



	## validate correct prefix when launching alt os
	%config = %{read_config("build/tests/areas/lib_wine/wine_os_test.conf")};
	%config_wine = %{$config{Wine}};
	popu_wine_config(\%config_wine);
	setup_wine_env();

	ok($ENV{WINEPREFIX} eq "$ENV{HOME}/.wine_7", "setup_wine_os: WINEPREFIX set") or warn "WINEPREFIX: $ENV{WINEPREFIX}\n" or die;



	#3 validate setting up os
	%config = %{read_config("build/tests/areas/lib_wine/wine_os_test2.conf")};
	%config_wine = %{$config{Wine}};
	popu_wine_config(\%config_wine);
	setup_wine_env();
	ok($ENV{WINEPREFIX} eq "$CWD/tmp/wine_7_validation", "setup_wine_os: WINEPREFIX override") or die;
	ok(check_wine_os("Windows 7"), "setup_wine_os: Wine setup validation") or die;
	ok(!check_wine_os("Windows XP"), "check_wine_os: negative validation") or die;
}


sub wine_setup_tests {
	print "\n\nStarting tests module: wine_setup\n";

	my $ret = system("./build/modules/11_wine_setup.pl", "./build/tests/areas/modules/empty_config.conf");
	ok($ret == 0, "wine_setup: empty config exits with 0") or die;
	
	$ret = system("./build/modules/11_wine_setup.pl", "./build/tests/areas/modules/wine_setup.conf");
	ok($ret == 0, "wine_setup: exits with 0") or die;

	ok( -d "./tmp/wine_setup_test/dosdevices", "wine_setup: wine area created") or die;

	
}



sub unpack_tests {
	my $ret;
	my $module = "./build/modules/12_unpack.pl";
	my $module_name = "unpack";
	print "\n\nStarting tests module: $module_name\n";

	$ret = system($module, "./build/tests/areas/modules/empty_config.conf");
	ok($ret == 0, "$module_name: empty config exits with 0") or die;

	$ret = system($module, "./build/tests/areas/modules/unpack/unpack.conf");
	ok($ret == 0, "$module_name: empty config exits with 0 - 2") or die;
	ok(-e "tmp/unlink_tests/unpack/test", "$module_name: successfull unpack") or die;


	unlink("tmp/unlink_tests/unpack/test");
	system($module, "./build/tests/areas/modules/unpack/unpack.conf");
	ok( ! -e "tmp/unlink_tests/unpack/test", "$module_name: successfull unpack") or die;
}



sub hybridize_tests {
	my $module = "./build/modules/01_hybridize.pl";
	my $module_name = "hybridize";


	print "\n\nStarting tests module: $module_name\n";
	my $ret = system($module, "./build/tests/areas/modules/empty_config.conf");
	ok($ret == 0, "$module_name: empty config exits with 0");

	$ret = system($module, "./build/tests/areas/modules/hybridize/hybridize.conf");

	ok($ret == 0, "$module_name: exits with 0");

	ok(-l "./tmp/hybridize_test/file_link", "hybridize: file link") or die;
	ok(-l "./tmp/hybridize_test/dir_link", "hybridize: dir link") or die;
	ok(-f "./tmp/hybridize_test/file", "hybridize: file") or die;
	ok(-d "./tmp/hybridize_test/dir", "hybridize: dir") or die;
}



sub modloader_tests {
	my $module = "./build/modules/80_modloader.pl";
	my $module_name = "modloader";


	print "\n\nStarting tests module: $module_name\n";
	mkdir("./tmp/modloader_tests");
	mkdir("./tmp/modloader_tests/mods");
	mkdir("./tmp/modloader_tests/mods_save");
	system("touch", "./tmp/modloader_tests/mods/whitelist");

	my $ret = system($module, "./build/tests/areas/empty_config.conf");
	ok($ret == 0, "$module_name: empty config exits with 0") or die;

	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_all_copy.conf");

	ok($ret == 0, "$module_name: exits with 0") or die;

	ok(-f "./tmp/modloader_tests/mods/mymod1", "modloader: loaded mymod1") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod2", "modloader: loaded mymod2") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod3", "modloader: loaded mymod3") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod4/dir1/stuff", "modloader: loaded mymod4") or die;
	ok(-f "./tmp/modloader_tests/mods/whitelist", "modloader: loaded whitelist") or die;



	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_all_link.conf");

	ok($ret == 0, "$module_name: exits with 0") or die;

	ok(-l "./tmp/modloader_tests/mods/mymod1", "modloader: loaded linked mymod1") or die;
	ok(-l "./tmp/modloader_tests/mods/mymod2", "modloader: loaded linked mymod2") or die;
	ok(-l "./tmp/modloader_tests/mods/mymod3", "modloader: loaded linked mymod3") or die;
	ok(-l "./tmp/modloader_tests/mods/mymod4", "modloader: loaded linked mymod4") or die;
	ok(-f "./tmp/modloader_tests/mods/whitelist", "modloader: loaded whitelist") or die;



	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_all_copy_save.conf");

	ok($ret == 0, "$module_name: exits with 0") or die;

	ok(-f "./tmp/modloader_tests/mods/mymod1", "$module_name: loaded linked mymod1") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod2", "$module_name: loaded linked mymod2") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod3", "$module_name: loaded linked mymod3") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod4/dir1/stuff", "modloader: loaded linked mymod4") or die;
	ok(-f "./tmp/modloader_tests/mods/whitelist", "$module_name: loaded whitelist") or die;

	system("echo test1 > ./tmp/modloader_tests/mods/mymod1");


	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_none_copy_save.conf");

	ok($ret == 0, "$module_name: exits with 0") or die;

	ok(-f "./tmp/modloader_tests/mods_save/mymod1", "$module_name: saved mymod1") or die;
	ok(-f "./tmp/modloader_tests/mods_save/mymod2", "$module_name: saved mymod2") or die;
	ok(-f "./tmp/modloader_tests/mods_save/mymod3", "$module_name: saved mymod3") or die;
	ok(-f "./tmp/modloader_tests/mods_save/mymod4/dir1/stuff", "$module_name: saved mymod4") or die;
	ok(! -f "./tmp/modloader_tests/mods_save/whitelist", "$module_name: didn't save whitelist") or die;
	ok(system("grep", "-q", "test1", "./tmp/modloader_tests/mods_save/mymod1") == 0, "$module_name: changes saved") or die;


	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_all_copy_save.conf");

	ok($ret == 0, "$module_name: exits with 0") or die;

	ok(-f "./tmp/modloader_tests/mods/mymod1", "$module_name: loaded linked mymod1") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod2", "$module_name: loaded linked mymod2") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod3", "$module_name: loaded linked mymod3") or die;
	ok(-f "./tmp/modloader_tests/mods/mymod4/dir1/stuff", "$module_name: loaded linked mymod4") or die;
	ok(-f "./tmp/modloader_tests/mods/whitelist", "$module_name: loaded whitelist") or die;

	ok(system("grep", "-q", "test1", "./tmp/modloader_tests/mods/mymod1") == 0, "$module_name: changes reloaded") or die;


	symlink("/some/place/that/doesnt/exist", "./tmp/modloader_tests/mods/nonexistant");
	system("zenity", "--info", "--text", "When the module list comes up select 'mymod1', and hit enter", "--title", "notice");
	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_ask_link.conf");

	ok($ret == 0, "$module_name: exits with 0") or die;


	ok(-f "./tmp/modloader_tests/mods/mymod1", "$module_name: ask loaded linked mymod1") or die;
	ok(! -f "./tmp/modloader_tests/mods/mymod2", "$module_name: ask unloaded linked mymod2") or die;
	ok(! -f "./tmp/modloader_tests/mods/mymod3", "$module_name: ask unlinked mymod3") or die;
	ok(! -d "./tmp/modloader_tests/mods/mymod4", "$module_name: ask unlinked mymod4") or die;
	ok(! -l "./tmp/modloader_tests/mods/nonexistant", "$module_name: Clean broken links") or die;
	ok(-f "./tmp/modloader_tests/mods/whitelist", "$module_name: loaded whitelist") or die;


	system("zenity", "--info", "--text", "If no modules screen shows up after this message hit 'no' for the next dialog", "notice");
	$ret = system($module, "./build/tests/areas/modules/modloader/modloader_ask_link_empty.conf");
	ok($ret == 0, "$module_name: return 0") or die;
	$ret = system("zenity", "--question", "--text", "Did a module screen show up?", "--title", "notice");
	ok($ret != 0, "$module_name: No mods in folder") or die;


}


sub wine_deps_tests {
	my $module = "./build/modules/88_wine_deps.pl";
	my $module_name = "wine_deps";

	print "\n\nStarting tests module: $module_name\n";
	my $ret;

	$ret = system($module, "./build/tests/areas/modules/wine_deps.conf");
	ok($ret == 0, "$module_name: exits with 0") or die;

	ok(-e "./tmp/wine_deps_test/drive_c/windows/system32/d3dx9_42.dll", "$module_name: 64 bit d3dx9_42") or die;
	ok(-e "./tmp/wine_deps_test/drive_c/windows/syswow64/d3dx9_42.dll", "$module_name: 32 bit d3dx9_42") or die;
	ok(-e "./tmp/wine_deps_test/drive_c/windows/system32/d3dx9_26.dll", "$module_name: 64 bit d3dx9_26") or die;
	ok(-e "./tmp/wine_deps_test/drive_c/windows/syswow64/d3dx9_26.dll", "$module_name: 32 bit d3dx9_26") or die;

	
	system("zenity", "--info", "--text", "If no wine screen shows up after this message hit 'no' for the next dialog", "notice");
	$ret = system($module, "./build/tests/areas/empty_config.conf");
	ok($ret == 0, "$module_name: exits with 0") or die;
	$ret = system("zenity", "--question", "--text", "Did a wine screen show up?", "--title", "notice");
	ok($ret != 0, "$module_name: handle blank wine config") or die;

}


sub prerun_script_tests {
	my $module = "./build/modules/89_prerun_script.pl";
	my $module_name = "prerun_script";

	print "\n\nStarting tests module: $module_name\n";
	my $ret;

	$ret = system($module, "./build/tests/areas/modules/empty_config.conf");
	ok($ret == 0, "$module_name: empty config exits with 0") or die;


	$ret = system($module, "build/tests/areas/modules/prerun_script/prerun_script.conf");
	ok($ret == 0, "$module_name: exits with 0") or die;
	ok( -e "tmp/prerun_script", "$module_name: script ran successfully") or die;
}

sub exec_tests {
	my $module = "./build/modules/91_exec.pl";
	my $module_name = "exec";

	print "\n\nStarting tests module: $module_name\n";
	my $ret;

	$ret = system($module, "./build/tests/areas/modules/empty_config.conf");
	ok($ret == 0, "$module_name: empty config exits with 0") or die;

	$ret = system($module, "build/tests/areas/modules/exec/exec.conf");
	ok($ret == 0, "$module_name: exits with 0") or die;

	ok( -e "./tmp/exec", "$module_name: script ran") or die;
	ok( system("grep", "-q", "Pass", "./tmp/exec") == 0, "$module_name: script arg1 shown") or die;
	ok( system("grep", "-q", "2:arg2", "./tmp/exec") == 0, "$module_name: script arg2 shown") or die;
}
