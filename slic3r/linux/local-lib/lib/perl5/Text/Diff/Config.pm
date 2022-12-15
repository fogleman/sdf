package Text::Diff::Config;

use 5.006;
use strict;
use warnings;

our $VERSION   = '1.44';
our $Output_Unicode;

BEGIN
{
    $Output_Unicode = $ENV{'DIFF_OUTPUT_UNICODE'};
}

1;

__END__

=pod

=head1 NAME

Text::Diff::Config - global configuration for Text::Diff (as a 
separate module).

=head1 SYNOPSIS

  use Text::Diff::Config;
  
  $Text::Diff::Config::Output_Unicode = 1;

=head1 DESCRIPTION

This module configures Text::Diff and its related modules. Currently it contains
only one global variable $Text::Diff::Config::Output_Unicode  which is a boolean
flag, that if set outputs unicode characters as themselves without escaping them 
as C< \x{HHHH} > first.

It is initialized to the value of C< $ENV{DIFF_OUTPUT_UNICODE} >, but can be
set to a different value at run-time, including using local.

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/> .

=head1 LICENSE

Copyright 2010, Shlomi Fish.

This file is licensed under the MIT/X11 License:
L<http://www.opensource.org/licenses/mit-license.php>.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut

package Text::Diff::Config;

use strict;
use warnings;

use vars qw($Output_Unicode);

BEGIN
{
    $Output_Unicode = $ENV{'DIFF_OUTPUT_UNICODE'};
}

1;

__END__

=pod

=head1 NAME

Text::Diff::Config - global configuration for Text::Diff (as a 
separate module).

=head1 SYNOPSIS

  use Text::Diff::Config;
  
  $Text::Diff::Config::Output_Unicode = 1;

=head1 DESCRIPTION

This module configures Text::Diff and its related modules. Currently it contains
only one global variable $Text::Diff::Config::Output_Unicode  which is a boolean
flag, that if set outputs unicode characters as themselves without escaping them 
as C< \x{HHHH} > first.

It is initialized to the value of C< $ENV{DIFF_OUTPUT_UNICODE} >, but can be
set to a different value at run-time, including using local.

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/> .

=head1 LICENSE

Copyright 2010, Shlomi Fish.

This file is licensed under the MIT/X11 License:
L<http://www.opensource.org/licenses/mit-license.php>.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut

