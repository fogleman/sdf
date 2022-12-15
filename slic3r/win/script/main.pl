
if (defined $ENV{PAR_APP_REUSE}) {
    warn "Executable was created without the --reusable option. See 'perldoc pp'.\n";
    exit(1);
}


my $zip = $PAR::LibCache{$ENV{PAR_PROGNAME}} || Archive::Zip->new(__FILE__);
my $member = eval { $zip->memberNamed('script/slic3r.pl') }
        or die qq(main.pl: Can't open perl script "script/slic3r.pl": No such file or directory ($zip));

# Remove everything but PAR hooks from @INC
my %keep = (
    \&PAR::find_par => 1,
    \&PAR::find_par_last => 1,
);
my $par_temp_dir = File::Spec->catdir( $ENV{PAR_TEMP} );
@INC =
    grep {
        exists($keep{$_})
        or $_ =~ /^\Q$par_temp_dir\E/;
    }
    @INC;


PAR::_run_member($member, 1);

