package Role::Tiny::With;

use strict;
use warnings;

our $VERSION = '2.000005';
$VERSION = eval $VERSION;

use Role::Tiny ();

use Exporter 'import';
our @EXPORT = qw( with );

sub with {
    my $target = caller;
    Role::Tiny->apply_roles_to_package($target, @_)
}

1;

=head1 NAME

Role::Tiny::With - Neat interface for consumers of Role::Tiny roles

=head1 SYNOPSIS

 package Some::Class;

 use Role::Tiny::With;

 with 'Some::Role';

 # The role is now mixed in

=head1 DESCRIPTION

C<Role::Tiny> is a minimalist role composition tool.  C<Role::Tiny::With>
provides a C<with> function to compose such roles.

=head1 AUTHORS

See L<Role::Tiny> for authors.

=head1 COPYRIGHT AND LICENSE

See L<Role::Tiny> for the copyright and license.

=cut


