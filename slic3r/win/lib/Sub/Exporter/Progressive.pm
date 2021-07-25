#line 1 "Sub/Exporter/Progressive.pm"
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

#line 175
