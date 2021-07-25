#line 1 "Class/Accessor.pm"
package Class::Accessor;
require 5.00502;
use strict;
$Class::Accessor::VERSION = '0.34';

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;

    $fields = {} unless defined $fields;

    # make a copy of $fields.
    bless {%$fields}, $class;
}

sub mk_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('rw', @fields);
}

if (eval { require Sub::Name }) {
    Sub::Name->import;
}

{
    no strict 'refs';

    sub import {
        my ($class, @what) = @_;
        my $caller = caller;
        for (@what) {
            if (/^(?:antlers|moose-?like)$/i) {
                *{"${caller}::has"} = sub {
                    my ($f, %args) = @_;
                    $caller->_mk_accessors(($args{is}||"rw"), $f);
                };
                *{"${caller}::extends"} = sub {
                    @{"${caller}::ISA"} = @_;
                    unless (grep $_->can("_mk_accessors"), @_) {
                        push @{"${caller}::ISA"}, $class;
                    }
                };
                # we'll use their @ISA as a default, in case it happens to be
                # set already
                &{"${caller}::extends"}(@{"${caller}::ISA"});
            }
        }
    }

    sub follow_best_practice {
        my($self) = @_;
        my $class = ref $self || $self;
        *{"${class}::accessor_name_for"}  = \&best_practice_accessor_name_for;
        *{"${class}::mutator_name_for"}  = \&best_practice_mutator_name_for;
    }

    sub _mk_accessors {
        my($self, $access, @fields) = @_;
        my $class = ref $self || $self;
        my $ra = $access eq 'rw' || $access eq 'ro';
        my $wa = $access eq 'rw' || $access eq 'wo';

        foreach my $field (@fields) {
            my $accessor_name = $self->accessor_name_for($field);
            my $mutator_name = $self->mutator_name_for($field);
            if( $accessor_name eq 'DESTROY' or $mutator_name eq 'DESTROY' ) {
                $self->_carp("Having a data accessor named DESTROY  in '$class' is unwise.");
            }
            if ($accessor_name eq $mutator_name) {
                my $accessor;
                if ($ra && $wa) {
                    $accessor = $self->make_accessor($field);
                } elsif ($ra) {
                    $accessor = $self->make_ro_accessor($field);
                } else {
                    $accessor = $self->make_wo_accessor($field);
                }
                my $fullname = "${class}::$accessor_name";
                my $subnamed = 0;
                unless (defined &{$fullname}) {
                    subname($fullname, $accessor) if defined &subname;
                    $subnamed = 1;
                    *{$fullname} = $accessor;
                }
                if ($accessor_name eq $field) {
                    # the old behaviour
                    my $alias = "${class}::_${field}_accessor";
                    subname($alias, $accessor) if defined &subname and not $subnamed;
                    *{$alias} = $accessor unless defined &{$alias};
                }
            } else {
                my $fullaccname = "${class}::$accessor_name";
                my $fullmutname = "${class}::$mutator_name";
                if ($ra and not defined &{$fullaccname}) {
                    my $accessor = $self->make_ro_accessor($field);
                    subname($fullaccname, $accessor) if defined &subname;
                    *{$fullaccname} = $accessor;
                }
                if ($wa and not defined &{$fullmutname}) {
                    my $mutator = $self->make_wo_accessor($field);
                    subname($fullmutname, $mutator) if defined &subname;
                    *{$fullmutname} = $mutator;
                }
            }
        }
    }

}

sub mk_ro_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('ro', @fields);
}

sub mk_wo_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('wo', @fields);
}

sub best_practice_accessor_name_for {
    my ($class, $field) = @_;
    return "get_$field";
}

sub best_practice_mutator_name_for {
    my ($class, $field) = @_;
    return "set_$field";
}

sub accessor_name_for {
    my ($class, $field) = @_;
    return $field;
}

sub mutator_name_for {
    my ($class, $field) = @_;
    return $field;
}

sub set {
    my($self, $key) = splice(@_, 0, 2);

    if(@_ == 1) {
        $self->{$key} = $_[0];
    }
    elsif(@_ > 1) {
        $self->{$key} = [@_];
    }
    else {
        $self->_croak("Wrong number of arguments received");
    }
}

sub get {
    my $self = shift;

    if(@_ == 1) {
        return $self->{$_[0]};
    }
    elsif( @_ > 1 ) {
        return @{$self}{@_};
    }
    else {
        $self->_croak("Wrong number of arguments received");
    }
}

sub make_accessor {
    my ($class, $field) = @_;

    return sub {
        my $self = shift;

        if(@_) {
            return $self->set($field, @_);
        } else {
            return $self->get($field);
        }
    };
}

sub make_ro_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;

        if (@_) {
            my $caller = caller;
            $self->_croak("'$caller' cannot alter the value of '$field' on objects of class '$class'");
        }
        else {
            return $self->get($field);
        }
    };
}

sub make_wo_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;

        unless (@_) {
            my $caller = caller;
            $self->_croak("'$caller' cannot access the value of '$field' on objects of class '$class'");
        }
        else {
            return $self->set($field, @_);
        }
    };
}


use Carp ();

sub _carp {
    my ($self, $msg) = @_;
    Carp::carp($msg || $self);
    return;
}

sub _croak {
    my ($self, $msg) = @_;
    Carp::croak($msg || $self);
    return;
}

1;

__END__

#line 745
