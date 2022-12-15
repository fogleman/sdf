package ExtUtils::XSpp::Exception;
use strict;
use warnings;

require ExtUtils::XSpp::Exception::unknown;
require ExtUtils::XSpp::Exception::simple;
require ExtUtils::XSpp::Exception::stdmessage;
require ExtUtils::XSpp::Exception::code;
require ExtUtils::XSpp::Exception::perlcode;
#require ExtUtils::XSpp::Exception::message;
require ExtUtils::XSpp::Exception::object;

=head1 NAME

ExtUtils::XSpp::Exception - Map C++ exceptions to Perl exceptions

=head1 DESCRIPTION

This class is both the base class for the different exception handling
mechanisms and the container for the global set of exception
mappings from C++ exceptions (indicated by a C++ data type to catch)
to Perl exceptions. The Perl exceptions are implemented via C<croak()>.

The basic idea is that you can declare the C++ exception types that
you want to handle and how you plan to do so by using the C<%exception>
directive in your XS++ (or better yet, in the XS++ typemap):

  // OutOfBoundsException would have been declared
  // elsewhere as:
  //
  // class OutOfBoundsException : public std::exception {
  // public:
  //   OutOfBoundsException() {}
  //   virtual const char* what() const throw() {
  //     return "You accessed me out of bounds, fool!";
  //   }
  // }
  
  %exception{outOfBounds}{OutOfBoundsException}{stdmessage};

If you know a function or method may throw C<MyOutOfBoundsException>s, you
can annotate the declaration in your XS++ as follows:

  double get_from_array(unsigned int index)
    %catch{outOfBounds};

When C<get_from_array> now throws an C<OutOfBoundsException>, the user
gets a Perl croak with the message
C<"Caught exception of type 'OutOfBoundsException': You accessed me out of bounds, fool!">.
There may be any number of C<%catch> directives per method.

I<Note:> Why do we assign another name (C<outOfBounds>) to the
existing C<OutOfBoundsException>?
Because you may need to catch exceptions of the same C++ type with different
handlers for different methods. You can, in principle, re-use the C++ exception
class name for the exception I<map> name, but that may be confusing to posterity.

Instead of adding C<%catch> to methods, you may also specify exceptions that
you wish to handle for all methods of a class:

  class Foo %catch{SomeException,AnotherException} {
    ...
  };

The C<%catch{Foo,Bar,...}> syntax is shorthand for C<%catch{Foo} %catch{Bar} ...>.
If there are exceptions to be caught both from the class and attached
to a method directly, the exceptions that are attached to the method only will
be handled first. No single type of exceptions will be handled more than once,
therefore it is safe to use this precedence to re-order the class-global
exception handling for a single method.

If there are no C<%catch> decorators on a method, exceptions derived
from C<std::exception> will be caught with a generic C<stdmessage>
handler such as above. Even if there are C<%catch> clauses for the given method,
all otherwise uncaught exceptions will be caught with a generic error message
for safety.

=head1 Exception handlers

There are different cases of Perl exceptions that are implemented
as sub-classes of C<ExtUtils::XSpp::Exception>:

=over 2

=item L<ExtUtils::XSpp::Exception::simple>

implements the most general case of simply throwing a
generic error message that includes the name of the
C++ exception type.

=item L<ExtUtils::XSpp::Exception::stdmessage>

handles C++ exceptions that are derived from C<std::exception> and
which provide a C<char* what()> method that will provide an error message.
The Perl-level error message will include the C++ exception type name
and the exception's C<what()> message.

=item L<ExtUtils::XSpp::Exception::code>

allows the user to supply custom C/C++/XS code that will be included in
the exception handler verbatim. The code has access to the exception
object as the variable C<e>. Your user supplied code
is expected to propagate the exception to Perl by calling croak().

=cut

=begin comment

=item L<ExtUtils::XSpp::Exception::message>

translates C++ exceptions to Perl error messages using a printf-like
mask for the message. Potentially filling in place-holders by calling
methods on the C++ exception object(!). Not yet implemented.
Details to be hammered out.

=end comment

=item L<ExtUtils::XSpp::Exception::object>

maps C++ exceptions to throwing an instance of some Perl exception class.

Syntax:

  %exception{myClassyException}{CppException}{object}{PerlClass};

Currently, this means just calling C<PerlClass-E<gt>new()> and
then die()ing with that object in C<$@>. There is no good way to pass
information from the C++ exception object to the Perl object.
Will change in future.

=item L<ExtUtils::XSpp::Exception::unknown>

is the default exception handler that is added to the list of handlers
automatically during code generation. It simply throws an entirely
unspecific error and catches the type C<...> (meaning I<anything>).

=cut

=begin comment

=item L<ExtUtils::XSpp::Exception::perlcode>

allows the user to supply custom Perl code that will be executed
in the exception handler. The code currently has no access to the
C++ exception object. It is supposed to return a scalar value
that is assigned to C<$@>.
Highly experimental.

=end comment

=back

There is a special exception handler C<nothing> which is always
available:

  int foo() %catch{nothing};

It indicates that the given method (or function) is to handle no
exceptions. It squishes any exception handlers that might otherwise
be inherited from the method's class.

=head1 METHODS

=cut

=head2 new

Creates a new C<ExtUtils::XSpp::Exception>.

Calls the C<$self-E<gt>init(@_)> method after construction.
C<init()> must be overridden in subclasses.

=cut

sub new {
  my $class = shift;
  my $this = bless {}, $class;

  $this->init( @_ );

  return $this;
}

sub init {
  my $self = shift;
  my %args = @_;
  $self->{TYPE} = $args{type};
  $self->{NAME} = $args{name};
}

=head2 handler_code

Unimplemented in this base class, but must be implemented
in all actual exception classes.

Generates the C<catch(){}> block of code for inclusion
in the XS output. First (optional) argument is an integer indicating
the number of spaces to use for the first indentation level.

=cut

sub handler_code {
  Carp::croak("Programmer left 'handler_code' method of his Exception subclass unimplemented");  
}

=head2 indent_code

Given a piece of code and a number of spaces to use for
global indentation, indents the code and returns it.

=cut

sub indent_code {
  my $this = shift;
  my $code = shift;
  my $n = shift;
  my $indent = " " x $n;
  $code =~ s/^/$indent/gm;
  return $code;
}

=head2 cpp_type

Fetches the C++ type of the exception from the C<type> attribute and returns it.

=cut

# TODO: Strip pointers and references
sub cpp_type {
  my $this = shift;
  return $this->type->print;
}

=head1 ACCESSORS

=head2 name

Returns the name of the exception.
This is the C<myException> in C<%exception{myException}{char*}{handler}>.

=cut

sub name { $_[0]->{NAME} }

=head2 type

Returns the L<ExtUtils::XSpp::Node::Type> C++ type that is used for this exception.
This is the C<char*> in C<%exception{myException}{char*}{handler}>.

=cut

sub type { $_[0]->{TYPE} }


=head1 CLASS METHODS

=cut

my %ExceptionsByName;
#my %ExceptionsByType;

=head2 add_exception

Given an C<ExtUtils::XSpp::Exception> object,
adds this object to the global registry, potentially
overwriting an exception map of the same name that was
in effect before.

=cut

sub add_exception {
  my ($class, $exception) = @_;

  $ExceptionsByName{$exception->name} = $exception;
  #push @{$ExceptionsByType{$exception->print} }, $exception;
  return();
}

=head2 get_exception_for_name

Given the XS++ name of the exception map, fetches
the corresponding C<ExtUtils::XSpp::Exception> object
from the global registry and returns it. Croaks on error.

=cut

sub get_exception_for_name {
  my ($class, $name) = @_;

  if (not exists $ExceptionsByName{$name}) {
    Carp::confess( "No Exception with the name $name declared" );
  }
  return $ExceptionsByName{$name};
}


1;
