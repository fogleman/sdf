#line 1 "Mozilla/CA.pm"
package Mozilla::CA;

use strict;
our $VERSION = '20160104';

use Cwd ();
use File::Spec ();
use File::Basename qw(dirname);

sub SSL_ca_file {
    my $file = File::Spec->catfile($ENV{PAR_TEMP}, qw(inc lib Mozilla CA cacert.pem));
    if (!File::Spec->file_name_is_absolute($file)) {
	$file = File::Spec->catfile(Cwd::cwd(), $file);
    }
    return $file;
}

1;

__END__

#line 75