package Sub::Exporter::Progressive;
$Sub::Exporter::Progressive::VERSION = '0.001013';
use strict;
use warnings;

# ABSTRACT: Only use Sub::Exporter if you need it

sub _croak {
  require Carp;
  &Carp::croak;
}

sub import {
   my ($self, @args) = @_;

   my $inner_target = caller;
   my $export_data = sub_export_options($inner_target, @args);

   my $full_exporter;
   no strict 'refs';
   no warnings 'once';
   @{"${inner_target}::EXPORT_OK"} = @{$export_data->{exports}};
   @{"${inner_target}::EXPORT"} = @{$export_data->{defaults}};
   %{"${inner_target}::EXPORT_TAGS"} = %{$export_data->{tags}};
   *{"${inner_target}::import"} = sub {
      use strict;
      my ($self, @args) = @_;

      if ( grep {
         length ref $_
            or
         $_ !~ / \A [:-]? \w+ \z /xm
      } @args ) {
         _croak 'your usage of Sub::Exporter::Progressive requires Sub::Exporter to be installed'
            unless eval { require Sub::Exporter };
         $full_exporter ||= Sub::Exporter::build_exporter($export_data->{original});

         goto $full_exporter;
      } elsif ( defined( (my ($num) = grep { m/^\d/ } @args)[0] ) ) {
         _croak "cannot export symbols with a leading digit: '$num'";
      } else {
         require Exporter;
         s/ \A - /:/xm for @args;
         @_ = ($self, @args);
         goto \&Exporter::import;
      }
   };
   return;
}

my $too_complicated = <<'DEATH';
You are using Sub::Exporter::Progressive, but the features your program uses from
Sub::Exporter cannot be implemented without Sub::Exporter, so you might as well
just use vanilla Sub::Exporter
DEATH

sub sub_export_options {
   my ($inner_target, $setup, $options) = @_;

   my @exports;
   my @defaults;
   my %tags;

   if ( ($setup||'') eq '-setup') {
      my %options = %$options;

      OPTIONS:
      for my $opt (keys %options) {
         if ($opt eq 'exports') {

            _croak $too_complicated if ref $options{exports} ne 'ARRAY';
            @exports = @{$options{exports}};
            _croak $too_complicated if grep { length ref $_ } @exports;

         } elsif ($opt eq 'groups') {
            %tags = %{$options{groups}};
            for my $tagset (values %tags) {
               _croak $too_complicated if grep {
                  length ref $_
                     or
                  $_ =~ / \A - (?! all \b ) /x
               } @{$tagset};
            }
            @defaults = @{$tags{default} || [] };
         } else {
            _croak $too_complicated;
         }
      }
      @{$_} = map { / \A  [:-] all \z /x ? @exports : $_ } @{$_} for \@defaults, values %tags;
      $tags{all} ||= [ @exports ];
      my %exports = map { $_ => 1 } @exports;
      my @errors = grep { not $exports{$_} } @defaults;
      _croak join(', ', @errors) . " is not exported by the $inner_target module\n" if @errors;
   }

   return {
      exports => \@exports,
      defaults => \@defaults,
      original => $options,
      tags => \%tags,
   };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Sub::Exporter::Progressive - Only use Sub::Exporter if you need it

=head1 VERSION

version 0.001013

=head1 SYNOPSIS

 package Syntax::Keyword::Gather;

 use Sub::Exporter::Progressive -setup => {
   exports => [qw( break gather gathered take )],
   groups => {
     default => [qw( break gather gathered take )],
   },
 };

 # elsewhere

 # uses Exporter for speed
 use Syntax::Keyword::Gather;

 # somewhere else

 # uses Sub::Exporter for features
 use Syntax::Keyword::Gather 'gather', take => { -as => 'grab' };

=head1 DESCRIPTION

L<Sub::Exporter> is an incredibly powerful module, but with that power comes
great responsibility, er- as well as some runtime penalties.  This module
is a C<Sub::Exporter> wrapper that will let your users just use L<Exporter>
if all they are doing is picking exports, but use C<Sub::Exporter> if your
users try to use C<Sub::Exporter>'s more advanced features, like
renaming exports, if they try to use them.

Note that this module will export C<@EXPORT>, C<@EXPORT_OK> and
C<%EXPORT_TAGS> package variables for C<Exporter> to work.  Additionally, if
your package uses advanced C<Sub::Exporter> features like currying, this module
will only ever use C<Sub::Exporter>, so you might as well use it directly.

=head1 CONTRIBUTORS

ilmari - Dagfinn Ilmari Mannsåker (cpan:ILMARI) <ilmari@ilmari.org>

mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

leont - Leon Timmermans (cpan:LEONT) <leont@cpan.org>

=head1 AUTHOR

Arthur Axel "fREW" Schmidt <Sub-Exporter-Progressive@afoolishmanifesto.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Arthur Axel "fREW" Schmidt.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
