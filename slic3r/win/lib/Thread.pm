#line 1 "Thread.pm"
package Thread;

use strict;
use warnings;
no warnings 'redefine';

our $VERSION = '3.04';
$VERSION = eval $VERSION;

BEGIN {
    use Config;
    if (! $Config{useithreads}) {
        die("This Perl not built to support threads\n");
    }
}

use threads 'yield';
use threads::shared;

require Exporter;
our @ISA = qw(Exporter threads);
our @EXPORT = qw(cond_wait cond_broadcast cond_signal);
our @EXPORT_OK = qw(async yield);

sub async (&;@) { return Thread->new(shift); }

sub done { return ! shift->is_running(); }

sub eval  { die("'eval' not implemented with 'ithreads'\n"); };
sub flags { die("'flags' not implemented with 'ithreads'\n"); };

1;

__END__

#line 274
