#line 1 "Pod/Usage.pm"
#############################################################################
# Pod/Usage.pm -- print usage messages for the running script.
#
# Copyright (c) 1996-2000 by Bradford Appleton. All rights reserved.
# Copyright (c) 2001-2016 by Marek Rouchal.
# This file is part of "Pod-Usage". Pod-Usage is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::Usage;
use strict;

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '1.69';  ## Current version of this package
require  5.006;    ## requires this Perl version or later

#use diagnostics;
use Carp;
use Config;
use Exporter;
use File::Spec;

@EXPORT = qw(&pod2usage);
BEGIN {
    $Pod::Usage::Formatter ||= 'Pod::Text';
    eval "require $Pod::Usage::Formatter";
    die $@ if $@;
    @ISA = ( $Pod::Usage::Formatter );
}

our $MAX_HEADING_LEVEL = 3;

##---------------------------------------------------------------------------

##---------------------------------
## Function definitions begin here
##---------------------------------

sub pod2usage {
    local($_) = shift;
    my %opts;
    ## Collect arguments
    if (@_ > 0) {
        ## Too many arguments - assume that this is a hash and
        ## the user forgot to pass a reference to it.
        %opts = ($_, @_);
    }
    elsif (!defined $_) {
      $_ = '';
    }
    elsif (ref $_) {
        ## User passed a ref to a hash
        %opts = %{$_}  if (ref($_) eq 'HASH');
    }
    elsif (/^[-+]?\d+$/) {
        ## User passed in the exit value to use
        $opts{'-exitval'} =  $_;
    }
    else {
        ## User passed in a message to print before issuing usage.
        $_  and  $opts{'-message'} = $_;
    }

    ## Need this for backward compatibility since we formerly used
    ## options that were all uppercase words rather than ones that
    ## looked like Unix command-line options.
    ## to be uppercase keywords)
    %opts = map {
        my ($key, $val) = ($_, $opts{$_});
        $key =~ s/^(?=\w)/-/;
        $key =~ /^-msg/i   and  $key = '-message';
        $key =~ /^-exit/i  and  $key = '-exitval';
        lc($key) => $val;
    } (keys %opts);

    ## Now determine default -exitval and -verbose values to use
    if ((! defined $opts{'-exitval'}) && (! defined $opts{'-verbose'})) {
        $opts{'-exitval'} = 2;
        $opts{'-verbose'} = 0;
    }
    elsif (! defined $opts{'-exitval'}) {
        $opts{'-exitval'} = ($opts{'-verbose'} > 0) ? 1 : 2;
    }
    elsif (! defined $opts{'-verbose'}) {
        $opts{'-verbose'} = (lc($opts{'-exitval'}) eq 'noexit' ||
                             $opts{'-exitval'} < 2);
    }

    ## Default the output file
    $opts{'-output'} = (lc($opts{'-exitval'}) eq 'noexit' ||
                        $opts{'-exitval'} < 2) ? \*STDOUT : \*STDERR
            unless (defined $opts{'-output'});
    ## Default the input file
    $opts{'-input'} = $ENV{PAR_0} || $0  unless (defined $opts{'-input'});

    ## Look up input file in path if it doesn't exist.
    unless ((ref $opts{'-input'}) || (-e $opts{'-input'})) {
        my $basename = $opts{'-input'};
        my $pathsep = ($^O =~ /^(?:dos|os2|MSWin32)$/i) ? ';'
                            : (($^O eq 'MacOS' || $^O eq 'VMS') ? ',' :  ':');
        my $pathspec = $opts{'-pathlist'} || $ENV{PATH} || $ENV{PERL5LIB};

        my @paths = (ref $pathspec) ? @$pathspec : split($pathsep, $pathspec);
        for my $dirname (@paths) {
            $_ = File::Spec->catfile($dirname, $basename)  if length;
            last if (-e $_) && ($opts{'-input'} = $_);
        }
    }

    ## Now create a pod reader and constrain it to the desired sections.
    my $parser = new Pod::Usage(USAGE_OPTIONS => \%opts);
    if ($opts{'-verbose'} == 0) {
        $parser->select('(?:SYNOPSIS|USAGE)\s*');
    }
    elsif ($opts{'-verbose'} == 1) {
        my $opt_re = '(?i)' .
                     '(?:OPTIONS|ARGUMENTS)' .
                     '(?:\s*(?:AND|\/)\s*(?:OPTIONS|ARGUMENTS))?';
        $parser->select( '(?:SYNOPSIS|USAGE)\s*', $opt_re, "DESCRIPTION/$opt_re" );
    }
    elsif ($opts{'-verbose'} >= 2 && $opts{'-verbose'} != 99) {
        $parser->select('.*');
    }
    elsif ($opts{'-verbose'} == 99) {
        my $sections = $opts{'-sections'};
        $parser->select( (ref $sections) ? @$sections : $sections );
        $opts{'-verbose'} = 1;
    }

    ## Check for perldoc
    my $progpath = $opts{'-perldoc'} ? $opts{'-perldoc'} :
        File::Spec->catfile($Config{scriptdirexp} 
	|| $Config{scriptdir}, 'perldoc');

    my $version = sprintf("%vd",$^V);
    if ($Config{versiononly} and $Config{startperl} =~ /\Q$version\E$/ ) {
      $progpath .= $version;
    }
    $opts{'-noperldoc'} = 1 unless -e $progpath;

    ## Now translate the pod document and then exit with the desired status
    if (      !$opts{'-noperldoc'}
         and  $opts{'-verbose'} >= 2
         and  !ref($opts{'-input'})
         and  $opts{'-output'} == \*STDOUT )
    {
       ## spit out the entire PODs. Might as well invoke perldoc
       print { $opts{'-output'} } ($opts{'-message'}, "\n") if($opts{'-message'});
       if(defined $opts{-input} && $opts{-input} =~ /^\s*(\S.*?)\s*$/) {
         # the perldocs back to 5.005 should all have -F
	 # without -F there are warnings in -T scripts
	 my $f = $1;
         my @perldoc_cmd = ($progpath);
	 if ($opts{'-perldocopt'}) {
           $opts{'-perldocopt'} =~ s/^\s+|\s+$//g;
	   push @perldoc_cmd, split(/\s+/, $opts{'-perldocopt'});
	 }
	 push @perldoc_cmd, ('-F', $f);
         unshift @perldoc_cmd, $opts{'-perlcmd'} if $opts{'-perlcmd'};
         system(@perldoc_cmd);
         if($?) {
           # RT16091: fall back to more if perldoc failed
           system(($Config{pager} || $ENV{PAGER} || '/bin/more'), $1);
         }
       } else {
         croak "Unspecified input file or insecure argument.\n";
       }
    }
    else {
       $parser->parse_from_file($opts{'-input'}, $opts{'-output'});
    }

    exit($opts{'-exitval'})  unless (lc($opts{'-exitval'}) eq 'noexit');
}

##---------------------------------------------------------------------------

##-------------------------------
## Method definitions begin here
##-------------------------------

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my %params = @_;
    my $self = {%params};
    bless $self, $class;
    if ($self->can('initialize')) {
        $self->initialize();
    } else {
        # pass through options to Pod::Text
        my %opts;
       	for (qw(alt code indent loose margin quotes sentence stderr utf8 width)) {
            my $val = $params{USAGE_OPTIONS}{"-$_"};
            $opts{$_} = $val if defined $val;
        }
        $self = $self->SUPER::new(%opts);
        %$self = (%$self, %params);
    }
    return $self;
}

# This subroutine was copied in whole-cloth from Pod::Select 1.60 in order to
# allow the ejection of Pod::Select from the core without breaking Pod::Usage.
# -- rjbs, 2013-03-18
sub _compile_section_spec {
    my ($section_spec) = @_;
    my (@regexs, $negated);

    ## Compile the spec into a list of regexs
    local $_ = $section_spec;
    s{\\\\}{\001}g;  ## handle escaped backward slashes
    s{\\/}{\002}g;   ## handle escaped forward slashes

    ## Parse the regexs for the heading titles
    @regexs = split(/\//, $_, $MAX_HEADING_LEVEL);

    ## Set default regex for ommitted levels
    for (my $i = 0; $i < $MAX_HEADING_LEVEL; ++$i) {
        $regexs[$i]  = '.*'  unless ((defined $regexs[$i])
                                     && (length $regexs[$i]));
    }
    ## Modify the regexs as needed and validate their syntax
    my $bad_regexs = 0;
    for (@regexs) {
        $_ .= '.+'  if ($_ eq '!');
        s{\001}{\\\\}g;       ## restore escaped backward slashes
        s{\002}{\\/}g;        ## restore escaped forward slashes
        $negated = s/^\!//;   ## check for negation
        eval "m{$_}";         ## check regex syntax
        if ($@) {
            ++$bad_regexs;
            carp qq{Bad regular expression /$_/ in "$section_spec": $@\n};
        }
        else {
            ## Add the forward and rear anchors (and put the negator back)
            $_ = '^' . $_  unless (/^\^/);
            $_ = $_ . '$'  unless (/\$$/);
            $_ = '!' . $_  if ($negated);
        }
    }
    return  (! $bad_regexs) ? [ @regexs ] : undef;
}

sub select {
    my ($self, @sections) = @_;
    if ($ISA[0]->can('select')) {
        $self->SUPER::select(@sections);
    } else {
        # we're using Pod::Simple - need to mimic the behavior of Pod::Select
        my $add = ($sections[0] eq '+') ? shift(@sections) : '';
        ## Reset the set of sections to use
        unless (@sections) {
          delete $self->{USAGE_SELECT} unless ($add);
          return;
        }
        $self->{USAGE_SELECT} = []
          unless ($add && $self->{USAGE_SELECT});
        my $sref = $self->{USAGE_SELECT};
        ## Compile each spec
        for my $spec (@sections) {
          my $cs = _compile_section_spec($spec);
          if ( defined $cs ) {
            ## Store them in our sections array
            push(@$sref, $cs);
          } else {
            carp qq{Ignoring section spec "$spec"!\n};
          }
        }
    }
}

# Override Pod::Text->seq_i to return just "arg", not "*arg*".
sub seq_i { return $_[1] }
# Override Pod::Text->cmd_i to return just "arg", not "*arg*".
# newer version based on Pod::Simple
sub cmd_i { return $_[2] }

# This overrides the Pod::Text method to do something very akin to what
# Pod::Select did as well as the work done below by preprocess_paragraph.
# Note that the below is very, very specific to Pod::Text and Pod::Simple.
sub _handle_element_end {
    my ($self, $element) = @_;
    if ($element eq 'head1') {
        $self->{USAGE_HEADINGS} = [ $$self{PENDING}[-1][1] ];
        if ($self->{USAGE_OPTIONS}->{-verbose} < 2) {
            $$self{PENDING}[-1][1] =~ s/^\s*SYNOPSIS\s*$/USAGE/;
        }
    } elsif ($element =~ /^head(\d+)$/ && $1) { # avoid 0
        my $idx = $1 - 1;
        $self->{USAGE_HEADINGS} = [] unless($self->{USAGE_HEADINGS});
        $self->{USAGE_HEADINGS}->[$idx] = $$self{PENDING}[-1][1];
        # we have to get rid of the lower headings
        splice(@{$self->{USAGE_HEADINGS}},$idx+1);
    }
    if ($element =~ /^head\d+$/) {
        $$self{USAGE_SKIPPING} = 1;
        if (!$$self{USAGE_SELECT} || !@{ $$self{USAGE_SELECT} }) {
            $$self{USAGE_SKIPPING} = 0;
        } else {
            my @headings = @{$$self{USAGE_HEADINGS}};
            for my $section_spec ( @{$$self{USAGE_SELECT}} ) {
                my $match = 1;
                for (my $i = 0; $i < $MAX_HEADING_LEVEL; ++$i) {
                    $headings[$i] = '' unless defined $headings[$i];
                    my $regex   = $section_spec->[$i];
                    my $negated = ($regex =~ s/^\!//);
                    $match  &= ($negated ? ($headings[$i] !~ /${regex}/)
                                         : ($headings[$i] =~ /${regex}/));
                    last unless ($match);
                } # end heading levels
                if ($match) {
                  $$self{USAGE_SKIPPING} = 0;
                  last;
                }
            } # end sections
        }

        # Try to do some lowercasing instead of all-caps in headings, and use
        # a colon to end all headings.
        if($self->{USAGE_OPTIONS}->{-verbose} < 2) {
            local $_ = $$self{PENDING}[-1][1];
            s{([A-Z])([A-Z]+)}{((length($2) > 2) ? $1 : lc($1)) . lc($2)}ge;
            s/\s*$/:/  unless (/:\s*$/);
            $_ .= "\n";
            $$self{PENDING}[-1][1] = $_;
        }
    }
    if ($$self{USAGE_SKIPPING} && $element !~ m/^over-|^[BCFILSZ]$/) {
        pop @{ $$self{PENDING} };
    } else {
        $self->SUPER::_handle_element_end($element);
    }
}

# required for Pod::Simple API
sub start_document {
    my $self = shift;
    $self->SUPER::start_document();
    my $msg = $self->{USAGE_OPTIONS}->{-message}  or  return 1;
    my $out_fh = $self->output_fh();
    print $out_fh "$msg\n";
}

# required for old Pod::Parser API
sub begin_pod {
    my $self = shift;
    $self->SUPER::begin_pod();  ## Have to call superclass
    my $msg = $self->{USAGE_OPTIONS}->{-message}  or  return 1;
    my $out_fh = $self->output_handle();
    print $out_fh "$msg\n";
}

sub preprocess_paragraph {
    my $self = shift;
    local $_ = shift;
    my $line = shift;
    ## See if this is a heading and we aren't printing the entire manpage.
    if (($self->{USAGE_OPTIONS}->{-verbose} < 2) && /^=head/) {
        ## Change the title of the SYNOPSIS section to USAGE
        s/^=head1\s+SYNOPSIS\s*$/=head1 USAGE/;
        ## Try to do some lowercasing instead of all-caps in headings
        s{([A-Z])([A-Z]+)}{((length($2) > 2) ? $1 : lc($1)) . lc($2)}ge;
        ## Use a colon to end all headings
        s/\s*$/:/  unless (/:\s*$/);
        $_ .= "\n";
    }
    return  $self->SUPER::preprocess_paragraph($_);
}

1; # keep require happy

__END__

#line 895

