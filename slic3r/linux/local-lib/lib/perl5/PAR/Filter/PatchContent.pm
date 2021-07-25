package PAR::Filter::PatchContent;
use 5.006;
use strict;
use warnings;
use base 'PAR::Filter';

=head1 NAME

PAR::Filter::PatchContent - Content patcher

=head1 SYNOPSIS

    # transforms $code
    PAR::Filter::PatchContent->apply(\$code, $filename, $name);

=head1 DESCRIPTION

This filter fixes PAR-incompatible modules; F<pp> applies it to modules
by default.

=cut

sub PATCH_CONTENT () { +{
    map { ref($_) ? $_ : lc($_) }
    'AutoLoader.pm' => [
        '$is_dosish = ' =>
        '$is_dosish = $^O eq \'cygwin\' || ',
    ],
    'MIME/Types.pm' => [
        'File::Spec->catfile(dirname(__FILE__),' =>
        'File::Spec->catfile($ENV{PAR_TEMP}, qw(inc lib MIME),',
    ],
    'Mozilla/CA.pm' => [
        'File::Spec->catfile(dirname(__FILE__), "CA", "cacert.pem")' =>
        'File::Spec->catfile($ENV{PAR_TEMP}, qw(inc lib Mozilla CA cacert.pem))',
    ],
    'Pod/Usage.pm' => [
        ' = $0' =>
        ' = $ENV{PAR_0} || $0',
    ],
    # Some versions of Spreadsheet::ParseExcel have a weird non-POD construct =cmmt
    # that is used to comment out a block of code. perl treats it as POD and strips it.
    # Since it's not POD, POD parsers ignore it.
    # PAR::Filter::PodStrip only strips valid POD. Hence we remove it here.
    'Spreadsheet/ParseExcel.pm' => [
        qr/^=cmmt\s+.*?^=cut\s*/sm =>
        '',
    ],
    'SQL/Parser.pm'      => [
        'my @dialects;' =>
        'require PAR;
         my @dialects = ();
         foreach my $member ( $PAR::LastAccessedPAR->members ) {
             next unless $member->fileName =~ m!\bSQL/Dialects/([^/]+)\.pm$!;
             push @dialects, $1;
         }
        ',
    ],
    'Tk.pm'             => [
        'foreach $dir (@INC)' => 
        'require PAR;
         if (my $member = PAR::unpar($0, $file, 1)) {
            $file =~ s![/\\\\]!_!g;
            return PAR::Heavy::_dl_extract($member,$file,$file);
         }
         if (my $member = PAR::unpar($0, my $name = $_[1], 1)) {
            $name =~ s![/\\\\]!_!g;
            return PAR::Heavy::_dl_extract($member,$name,$name);
         }
         foreach $dir (@INC)', 
    ],
    'Tk/Widget.pm'          => [
        'if (defined($name=$INC{"$pkg.pm"}))' =>
        'if (defined($name=$INC{"$pkg.pm"}) and !ref($name) and $name !~ m!^/loader/!)',
    ],
    'Win32/API/Type.pm'     => [
        'INIT ' => '',
    ],
    'Win32/SystemInfo.pm'   => [
        '$dll .= "cpuspd.dll";' =>
        'require PAR;
         $dll = "lib/Win32/cpuspd.dll";
         if (my $member = PAR::unpar($0, $dll, 1)) {
             $dll = PAR::Heavy::_dl_extract($member,"cpuspd.dll","cpuspd.dll");
             $dll =~ s!\\\\!/!g;
         } else { die $! }',
    ],
    'XSLoader.pm'     => [
        'goto retry unless $module and defined &dl_load_file;' =>
            'goto retry;',                              # XSLoader <= 0.10
        'goto \&XSLoader::bootstrap_inherit unless $module and defined &dl_load_file;' =>
            'goto \&XSLoader::bootstrap_inherit;',      # XSLoader >= 0.14
    ],
    'diagnostics.pm'        => [
        'CONFIG: ' => 'CONFIG: if (0) ',
        'if (eof(POD_DIAG)) ' => 'if (0 and eof(POD_DIAG)) ',
        'close POD_DIAG' => '# close POD_DIAG',
        'while (<POD_DIAG>) ' =>
        'require PAR; use Config;
        my @files = (
            "lib/pod/perldiag.pod",
            "lib/Pod/perldiag.pod",
            "lib/pod/perldiag-$Config{version}.pod",
            "lib/Pod/perldiag-$Config{version}.pod",
            "lib/pods/perldiag.pod",
            "lib/pods/perldiag-$Config{version}.pod",
        );
        my $contents;
        foreach my $file (@files) {
            $contents = PAR::read_file($file);
            last if defined $contents;
        }
        for(map "$_\\n\\n", split/(?:\\r?\\n){2,}/, $contents) ',
    ],
    'utf8_heavy.pl'	    => [
        '$list ||= eval { $caller->$type(); }'
        => '$list = eval { $caller->$type(); }',
    '|| croak("Can\'t find $encoding character property definition via $caller->$type or $file.pl")'
        => '|| croak("Can\'t find $encoding character property definition via $caller->$type or $file.pl") unless $list;'
    ],
} };

sub apply {
    my ($class, $ref, $filename, $name) = @_;
    { use bytes; $$ref =~ s/^\xEF\xBB\xBF//; } # remove utf8 BOM

    my @rule = @{PATCH_CONTENT->{lc($name)}||[]} or return $$ref;
    while (my ($from, $to) = splice(@rule, 0, 2)) {
        if (ref($from) eq 'Regexp') {
            $$ref =~ s/$from/$to/g;
        }
        else {
            $$ref =~ s/\Q$from\E/$to/g;
        }
    }
    return $$ref;
}

1;

=head1 SEE ALSO

L<PAR::Filter>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par-packer@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2003-2009 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut
