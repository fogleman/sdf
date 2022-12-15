package Parse::Binary;
$Parse::Binary::VERSION = '0.11';

use 5.005;
use bytes;
use strict;
use integer;
use Parse::Binary::FixedFormat;

=head1 NAME

Parse::Binary - Unpack binary data structures into object hierarchies

=head1 VERSION

This document describes version 0.11 of Parse::Binary, released
January 25, 2009.

=head1 SYNOPSIS

# This class represents a Win32 F<.ico> file:

    package IconFile;
    use base 'Parse::Binary';
    use constant FORMAT => (
	Magic		=> 'a2',
	Type		=> 'v',
	Count		=> 'v',
	'Icon'		=> [ 'a16', '{$Count}', 1 ],
	Data		=> 'a*',
    );

# An individual icon resource:

    package Icon;
    use base 'Parse::Binary';
    use constant FORMAT => (
	Width		=> 'C',
	Height		=> 'C',
	ColorCount	=> 'C',
	Reserved	=> 'C',
	Planes		=> 'v',
	BitCount	=> 'v',
	ImageSize	=> 'V',
	ImageOffset	=> 'v',
    );
    sub Data {
	my ($self) = @_;
	return $self->parent->substr($self->ImageOffset, $self->ImageSize);
    }

# Simple F<.ico> file dumper that uses them:

    use IconFile;
    my $icon_file = IconFile->new('input.ico');
    foreach my $icon ($icon_file->members) {
	print "Dimension: ", $icon->Width, "x", $icon->Height, $/;
	print "Colors: ", 2 ** $icon->BitCount, $/;
	print "Image Size: ", $icon->ImageSize, " bytes", $/;
	print "Actual Size: ", length($icon->Data), " bytes", $/, $/;
    }
    $icon_file->write('output.ico'); # save as another .ico file

=head1 DESCRIPTION

This module makes parsing binary data structures much easier, by serving
as a base class for classes that represents the binary data, which may
contain objects of other classes to represent parts of itself.

Documentation is unfortunately a bit lacking at this moment.  Please read
the tests and source code of L<Parse::AFP> and L<Win32::Exe> for examples
of using this module.

=cut

use constant PROPERTIES	    => qw(
    %struct $filename $size $parent @siblings %children
    $output $lazy $iterator $iterated
);
use constant ENCODED_FIELDS => ( 'Data' );
use constant FORMAT	    => ( Data => 'a*' );
use constant SUBFORMAT	    => ();
use constant DEFAULT_ARGS   => ();
use constant DELEGATE_SUBS  => ();
use constant DISPATCH_TABLE => ();

use constant DISPATCH_FIELD => undef;
use constant BASE_CLASS	    => undef;
use constant ENCODING	    => undef;
use constant PADDING	    => undef;

unless (eval { require Scalar::Util; 1 }) {
    *Scalar::Util::weaken = sub { 1 };
    *Scalar::Util::blessed = sub { UNIVERSAL::can($_[0], 'can') };
}

### Constructors ###

sub new {
    my ($self, $input, $attr) = @_;

    no strict 'refs';
    my $class = $self->class;
    $class->init unless ${"$class\::init_done"};

    $attr ||= {};
    $attr->{filename} ||= $input unless ref $input;

    my $obj = $class->spawn;
    %$obj = (%$obj, %$attr);

    my $data = $obj->read_data($input);
    $obj->load($data, $attr);

    if ($obj->{lazy}) {
	$obj->{lazy} = $obj;
    }
    elsif (!$obj->{iterator}) {
	$obj->make_members;
    }

    return $obj;
}

sub dispatch_field {
    return undef;
}

use vars qw(%HasMembers %DefaultArgs);
use vars qw(%Fields %MemberFields %MemberClass %Packer %Parser %FieldPackFormat);
use vars qw(%DispatchField %DispatchTable);

sub init {
    no strict 'refs';
    return if ${"$_[0]\::init_done"};

    my $class = shift;

    *{"$class\::class"} = sub { ref($_[0]) || $_[0] };
    *{"$class\::is_type"} = \&is_type;

    foreach my $item ($class->PROPERTIES) {
	no strict 'refs';
	my ($sigil, $name) = split(//, $item, 2);
	*{"$class\::$name"} =
	    ($sigil eq '$') ? sub { $_[0]{$name} } :
	    ($sigil eq '@') ? sub { wantarray ? @{$_[0]{$name}||=[]} : ($_[0]{$name}||=[]) } :
	    ($sigil eq '%') ? sub { $_[0]{$name}||={} } :
	    die "Unknown sigil: $sigil";
	*{"$class\::set_$name"} =
	    ($sigil eq '$') ? sub { $_[0]->{$name} = $_[1] } :
	    ($sigil eq '@') ? sub { @{$_[0]->{$name}||=$_[1]||[]} = @{$_[1]||[]} } :
	    ($sigil eq '%') ? sub { %{$_[0]->{$name}||=$_[1]||{}} = %{$_[1]||{}} } :
	    die "Unknown sigil: $sigil";
    }

    my @args = $class->default_args;
    *{"$class\::default_args"} = \@args;
    *{"$class\::default_args"} = sub { @args };
    my $delegate_subs = $class->delegate_subs;
    if (defined(&{"$class\::DELEGATE_SUBS"})) {
	$delegate_subs = { $class->DELEGATE_SUBS };
    }
    *{"$class\::delegate_subs"} = sub { $delegate_subs };
    while (my ($subclass, $methods) = each %$delegate_subs) {
	$methods = [ $methods ] unless ref $methods;
	foreach my $method (grep length, @$methods) {
	    *{"$class\::$method"} = sub {
		goto &{$_[0]->require_class($subclass)->can($method)};
	    };
	}
    }
    my $dispatch_table = $class->dispatch_table;
    if (defined(&{"$class\::DISPATCH_TABLE"})) {
	$dispatch_table = { $class->DISPATCH_TABLE };
    }
    $DispatchTable{$class} = $dispatch_table;
    *{"$class\::dispatch_table"} = sub { $dispatch_table };

    my $dispatch_field = undef;
    if (defined(&{"$class\::DISPATCH_FIELD"})) {
	$dispatch_field = $class->DISPATCH_FIELD;
    }
    $DispatchField{$class} = $dispatch_field;
    *{"$class\::dispatch_field"} = sub { $dispatch_field };

    my @format = $class->format_list;
    if (my @subformat = $class->subformat_list) {
	my @new_format;
	while (my ($field, $format) = splice(@format, 0, 2)) {
	    if ($field eq 'Data') {
		push @new_format, @subformat;
	    }
	    else {
		push @new_format, ($field => $format);
	    }
	}
	@format = @new_format;
    }
    my @format_list = @format;
    *{"$class\::format_list"} = sub { @format_list };

    my (@fields, @formats, @pack_formats, $underscore_count);
    my (%field_format, %field_pack_format);
    my (%field_parser, %field_packer, %field_length);
    my (@member_fields, %member_class);
    while (my ($field, $format) = splice(@format, 0, 2)) {
	if ($field eq '_') {
	    # "we don't care" fields 
	    $underscore_count++;
	    $field = "_${underscore_count}_$class";
	    $field =~ s/:/_/g;
	}

	if (ref $format) {
	    $member_class{$field} = $class->classname($field);
	    $field =~ s/:/_/g;
	    $member_class{$field} = $class->classname($field);
	    $class->require($member_class{$field});
	    push @member_fields, $field;
	}
	else {
	    $format = [ $format ];
	}

	push @fields, $field;

	my $string = join(':', $field, @$format);
	$field_format{$field} = [ @$format ];
	if (!grep /\{/, @$format) {
	    $field_length{$field} = length(pack($format->[0], 0));
	    $field_parser{$field} = Parse::Binary::FixedFormat->new( [ $string ] );
	}
	push @formats, $string;

	s/\s*X\s*//g for @$format;
	my $pack_string = join(':', $field, @$format);
	$field_pack_format{$field} = [ @$format ];
	$field_packer{$field} = Parse::Binary::FixedFormat->new( [ $pack_string ] );
	push @pack_formats, $pack_string;
    }

    my $parser = $class->make_formatter(@formats);
    my $packer = $class->make_formatter(@pack_formats);

    $Packer{$class} = $packer;
    $Parser{$class} = $parser;
    $Fields{$class} = \@fields;
    $HasMembers{$class} = @member_fields ? 1 : 0;
    $DefaultArgs{$class} = \@args;
    $MemberClass{$class} = \%member_class;
    $MemberFields{$class} = \@member_fields;
    $FieldPackFormat{$class} = { map { ref($_) ? $_->[0] : $_ } %field_pack_format };

    *{"$class\::fields"} = \@fields;
    *{"$class\::member_fields"} = \@member_fields;
    *{"$class\::has_members"} = @member_fields ? sub { 1 } : sub { 0 };
    *{"$class\::fields"} = sub { @fields };
    *{"$class\::formats"} = sub { @formats };
    *{"$class\::member_fields"} = sub { @member_fields };
    *{"$class\::member_class"} = sub { $member_class{$_[1]} };
    *{"$class\::pack_formats"} = sub { @pack_formats };
    *{"$class\::field_format"} = sub { $field_format{$_[1]}[0] };
    *{"$class\::field_pack_format"} = sub { $field_pack_format{$_[1]}[0] };
    *{"$class\::field_length"} = sub { $field_length{$_[1]} };

    *{"$class\::parser"} = sub { $parser };
    *{"$class\::packer"} = sub { $packer };
    *{"$class\::field_parser"} = sub {
	my ($self, $field) = @_;
	$field_parser{$field} || do {
	    Parse::Binary::FixedFormat->new( [
		$self->eval_format(
		    $self->{struct},
		    join(':', $field, @{$field_format{$field}}),
		),
	    ] );
	};
    };

    *{"$class\::field_packer"} = sub { $field_packer{$_[1]} };
    *{"$class\::has_field"} = sub { $field_packer{$_[1]} };

    my %enc_fields = map { ($_ => 1) } $class->ENCODED_FIELDS;

    foreach my $field (@fields) {
	next if defined &{"$class\::$field"};

	if ($enc_fields{$field} and my $encoding = $class->ENCODING) {
	    require Encode;

	    *{"$class\::$field"} = sub {
		my ($self) = @_;
		return Encode::decode($encoding => $self->{struct}{$field});
	    };

	    *{"$class\::Set$field"} = sub {
		my ($self, $data) = @_;
		$self->{struct}{$field} = Encode::encode($encoding => $data);
	    };
	    next;
	}

	*{"$class\::$field"} = sub { $_[0]->{struct}{$field} };
	*{"$class\::Set$field"} = sub { $_[0]->{struct}{$field} = $_[1] };
    }

    ${"$class\::init_done"} = 1;
}

sub initialize {
    return 1;
}

### Miscellanous ###

sub field {
    my ($self, $field) = @_;
    return $self->{struct}{$field};
}

sub set_field {
    my ($self, $field, $data) = @_;
    $self->{struct}{$field} = $data;
}

sub classname {
    my ($self, $class) = @_;
    return undef unless $class;

    $class =~ s/__/::/g;

    my $base_class = $self->BASE_CLASS or return $class;
    return $base_class if $class eq '::BASE::';

    return "$base_class\::$class";
}

sub member_fields {
    return ();
}

sub dispatch_class {
    my ($self, $field) = @_;
    my $table = $DispatchTable{ref $self};
    my $class = exists($table->{$field}) ? $table->{$field} : $table->{'*'};

    $class = &$class($self, $field) if UNIVERSAL::isa($class, 'CODE');
    defined $class or return;

    if (my $members = $self->{parent}{callback_members}) {
	return unless $members->{$class};
    }
    my $subclass = $self->classname($class) or return;
    return if $subclass eq $class;
    return $subclass;
}

sub require {
    my ($class, $module) = @_;
    return unless defined $module;

    my $file = "$module.pm";
    $file =~ s{::}{/}g;

    return $module if (eval { require $file; 1 });
    die $@ unless $@ =~ /^Can't locate /;
    return;
}

sub require_class {
    my ($class, $subclass) = @_;
    return $class->require($class->classname($subclass));
}

sub format_list {
    my ($self) = @_;
    return $self->FORMAT;
}

sub subformat_list {
    my ($self) = @_;
    $self->SUBFORMAT ? $self->SUBFORMAT : ();
}

sub default_args {
    my ($self) = @_;
    $self->DEFAULT_ARGS ? $self->DEFAULT_ARGS : ();
}

sub dispatch_table {
    my ($self) = @_;
    $self->DISPATCH_TABLE ? { $self->DISPATCH_TABLE } : {};
}

sub delegate_subs {
    my ($self) = @_;
    $self->DELEGATE_SUBS ? { $self->DELEGATE_SUBS } : {};
}

sub class {
    my ($self) = @_;
    return(ref($self) || $self);
}

sub make_formatter {
    my ($self, @formats) = @_;
    return Parse::Binary::FixedFormat->new( $self->make_format(@formats) );
}

sub make_format {
    my ($self, @formats) = @_;
    return \@formats unless grep /\{/, @formats;

    my @prefix;
    foreach my $format (@formats) {
	last if $format =~ /\{/;
	push @prefix, $format;
    }
    return {
	Chooser => sub { $self->chooser(@_) },
	Formats => [ \@prefix, \@formats ],
    };
}

sub chooser {
    my ($self, $rec, $obj, $mode) = @_;
    my $idx = @{$obj->{Layouts}};
    my @format = $self->eval_format($rec, @{$obj->{Formats}[1]});
    $obj->{Layouts}[$idx] = $self->make_formatter(@format);
    return $idx;
}

sub eval_format {
    my ($self, $rec, @format) = @_;
    foreach my $key (sort keys %$rec) {
	s/\$$key\b/$rec->{$key}/ for @format;
    }
    !/\$/ and s/\{(.*?)\}/$1/eeg for @format;
    die $@ if $@;
    return @format;
}

sub padding {
    return '';
}

sub load_struct {
    my ($self, $data) = @_;
    $self->{struct} = $Parser{ref $self}->unformat($$data . $self->padding, $self->{lazy}, $self);
}

sub load_size {
    my ($self, $data) = @_;
    $self->{size} = length($$data);
    return 1;
}

sub lazy_load {
    my ($self) = @_;
    ref(my $sub = $self->{lazy}) or return;
    $self->{lazy} = 1;
    $self->make_members unless $self->{iterator};
}

my %DispatchClass;
sub load {
    my ($self, $data, $attr) = @_;
    return $self unless defined $data;

    no strict 'refs';
    my $class = ref($self) || $self;
    $class->init unless ${"$class\::init_done"};

    $self->load_struct($data);
    $self->load_size($data);

    if (my $field = $DispatchField{$class}) {
	if (
	    my $subclass = $DispatchClass{$class}{ $self->{struct}{$field} }
		||= $self->dispatch_class( $self->{struct}{$field})
	) {
	    $self->require($subclass);
	    bless($self, $subclass);
	    $self->load($data, $attr);
	}
    }

    return $self;
}

my (%classname, %fill_cache);
sub spawn {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    no strict 'refs';

    if (my $subclass = delete($args{Class})) {
	$class = $classname{$subclass} ||= do {
	    my $name = $self->classname($subclass);
	    $self->require($name);
	    $name->init;
	    $name;
	};
    }

    bless({
	struct => {
	    %args,
	    @{ $DefaultArgs{$class} },
	    %{ $fill_cache{$class} ||= $class->fill_in },
	},
    }, $class);
}

sub fill_in {
    my $class = shift;
    my $entries = {};

    foreach my $super_class ($class->superclasses) {
	my $field = $DispatchField{$super_class} or next;
	my $table = $DispatchTable{$super_class} or next;
	foreach my $code (reverse sort keys %$table) {
	    $class->is_type($table->{$code}) or next;
	    $entries->{$field} = $code;
	    last;
	}
    }

    return $entries;
}

sub spawn_sibling {
    my ($self, %args) = @_;
    my $parent = $self->{parent} or die "$self has no parent";

    my $obj = $self->spawn(%args);
    @{$obj}{qw( lazy parent output siblings )} =
	@{$self}{qw( lazy parent output siblings )};
    $obj->{size} = length($obj->dump);
    $obj->refresh_parent;
    $obj->initialize;

    return $obj;
}

sub sibling_index {
    my ($self, $obj) = @_;
    $obj ||= $self;

    my @siblings = @{$self->{siblings}};
    foreach my $index (($obj->{index}||0) .. $#siblings) {
	return $index if $obj == $siblings[$index];
    }

    return undef;
}

sub gone {
    my ($self, $obj) = @_;
    $self->{parent}{struct}{Data} .= ($obj || $self)->dump;
}

sub prepend_obj {
    my ($self, %args) = @_;
    if ($self->{lazy}) {
	my $obj = $self->spawn(%args);
	$self->gone($obj);
	return;
    }
    my $obj = $self->spawn_sibling(%args);
    my $siblings = $self->{siblings};
    my $index = $self->{index} ? $self->{index}++ : $self->sibling_index;
    $obj->{index} = $index;

    splice(@$siblings, $index, 0, $obj);
    return $obj;
}

sub append_obj {
    my ($self, %args) = @_;
    my $obj = $self->spawn_sibling(%args);

    @{$self->{siblings}} = (
	map { $_, (($_ == $self) ? $obj : ()) } @{$self->{siblings}}
    );
    return $obj;
}

sub remove {
    my ($self, %args) = @_;
    my $siblings = $self->{siblings};
    splice(@$siblings, $self->sibling_index, 1, undef);

    Scalar::Util::weaken($self->{parent});
    Scalar::Util::weaken($self);
}

sub read_data {
    my ($self, $data) = @_;
    return undef unless defined $data;
    return \($data->dump) if UNIVERSAL::can($data, 'dump');
    return $data if UNIVERSAL::isa($data, 'SCALAR');
    return \($self->read_file($data));
}

sub read_file {
    my ($self, $file) = @_;

    local *FH; local $/;
    open FH, "< $file" or die "Cannot open $file for reading: $!";
    binmode(FH);

    return scalar <FH>;
}

sub make_members {
    my ($self) = @_;

    $HasMembers{ref $self} or return;
    %{$self->{children}} = ();

    foreach my $field (@{$MemberFields{ref $self}}) {
	my ($format) = $self->eval_format(
	    $self->{struct},
	    $FieldPackFormat{ref $self}{$field},
	);

	my $members = [ map {
	    $self->new_member( $field, \pack($format, @$_) )
	} $self->validate_memberdata($field) ];
	$self->set_field_children( $field, $members );
    }
}

sub set_members {
    my ($self, $field, $members) = @_;
    $field =~ s/:/_/g;
    $self->set_field_children(
	$field,
	[ map { $self->new_member( $field, $_ ) } @$members ],
    );
}

sub set_field_children {
    my ($self, $field, $data) = @_;
    my $children = $self->field_children($field);
    @$children = @$data;
    return $children;
}

sub field_children {
    my ($self, $field) = @_;
    my $children = ($self->{children}{$field} ||= []);
    # $_->lazy_load for @$children;
    return(wantarray ? @$children : $children);
}

sub validate_memberdata {
    my ($self, $field) = @_;
    return @{$self->{struct}{$field}||[]};
}

sub first_member {
    my ($self, $type) = @_;
    $self->lazy_load;

    return undef unless $HasMembers{ref $self};

    no strict 'refs';
    foreach my $field (@{$MemberFields{ref $self}}) {
	foreach my $member ($self->field_children($field)) {
	    return $member if $member->is_type($type);
	}
    }
    return undef;
}

sub next_member {
    my ($self, $type) = @_;
    return undef unless $HasMembers{ref $self};

    if ($self->{lazy} and !$self->{iterated}) {
	if (ref($self->{lazy})) {
	    %{$self->{children}} = ();
	    $self->{iterator} = $self->make_next_member;
	    $self->lazy_load;
	}

	while (my $member = &{$self->{iterator}}) {
	    return $member if $member->is_type($type);
	}
	$self->{iterated} = 1;
	return;
    }

    $self->{_next_member}{$type} ||= $self->members($type);

    shift(@{$self->{_next_member}{$type}})
	|| undef($self->{_next_member}{$type});
}

sub make_next_member {
    my $self = shift;
    my $class = ref($self);
    my ($field_idx, $item_idx, $format) = (0, 0, undef);
    my @fields = @{$MemberFields{$class}};
    my $struct = $self->{struct};
    my $formats = $FieldPackFormat{$class};

    sub { LOOP: {
	my $field = $fields[$field_idx] or return;

	my $items = $struct->{$field};
	if ($item_idx > $#$items) {
	    $field_idx++;
	    $item_idx = 0;
	    undef $format;
	    redo;
	}

	$format ||= ($self->eval_format( $struct, $formats->{$field} ))[0];

	my $item = $items->[$item_idx++];
	$item = $item->($self, $items) if UNIVERSAL::isa($item, 'CODE');
	$self->valid_memberdata($item) or redo;

	my $member = $self->new_member( $field, \pack($format, @$item) );
	$member->{index} = (push @{$self->{children}{$field}}, $member) - 1;
	return $member;
    } };
}

sub members {
    my ($self, $type) = @_;
    $self->lazy_load;

    no strict 'refs';
    my @members = map {
	grep { $type ? $_->is_type($type) : 1 } $self->field_children($_)
    } @{$MemberFields{ref $self}};
    wantarray ? @members : \@members;
}

sub members_recursive {
    my ($self, $type) = @_;
    my @members = (
	( $self->is_type($type) ? $self : () ),
	map { $_->members_recursive($type) } $self->members
    );
    wantarray ? @members : \@members;
}

sub new_member {
    my ($self, $field, $data) = @_;
    my $obj = $MemberClass{ref $self}{$field}->new(
	$data, { lazy => $self->{lazy}, parent => $self }
    );

    $obj->{output} = $self->{output};
    $obj->{siblings} = $self->{children}{$field}||=[];
    $obj->initialize;

    return $obj;
}

sub valid_memberdata {
    length($_[-1][0])
}

sub dump_members {
    my ($self) = @_;
    return $Packer{ref $self}->format($self->{struct});
}

sub dump {
    my ($self) = @_;
    return $self->dump_members if $HasMembers{ref $self};
    return $Packer{ref $self}->format($self->{struct});
}

sub write {
    my ($self, $file) = @_;

    if (ref($file)) {
	$$file = $self->dump;
    }
    elsif (!defined($file) and my $fh = $self->{output}) {
	print $fh $self->dump;
    }
    else {
	$file = $self->{filename} unless defined $file;
	$self->write_file($file, $self->dump) if defined $file;
    }
}

sub write_file {
    my ($self, $file, $data) = @_;
    local *FH;
    open FH, "> $file" or die "Cannot open $file for writing: $!";
    binmode(FH);
    print FH $data;
};

sub superclasses {
    my ($self) = @_;
    my $class = $self->class;

    no strict 'refs';
    return @{"$class\::ISA"};
}

my %type_cache;
sub is_type {
    my ($self, $type) = @_;
    return 1 unless defined $type;

    my $class = ref($self) || $self;

    if (exists $type_cache{$class}{$type}) {
	return $type_cache{$class}{$type};
    }

    $type_cache{$class}{$type} = 1;


    $type =~ s/__/::/g;
    $type =~ s/[^\w:]//g;
    return 1 if ($class =~ /::$type$/);

    no strict 'refs';
    foreach my $super_class ($class->superclasses) {
	return 1 if $super_class->is_type($type);
    };

    $type_cache{$class}{$type} = 0;
}

sub refresh {
    my ($self) = @_;

    foreach my $field (@{$MemberFields{ref $self}}) {
	my $parser = $self->field_parser($field);
	my $padding = $self->padding;

	local $SIG{__WARN__} = sub {};
	@{$self->{struct}{$field}} = map {
	    $parser->unformat( $_->dump . $padding, 0, $self)->{$field}[0]
	} grep defined, @{$self->{children}{$field}||[]};

	$self->validate_memberdata;
    }

    $self->refresh_parent;
}

sub refresh_parent {
    my ($self) = @_;
    my $parent = $self->{parent} or return;
    $parent->refresh unless !Scalar::Util::blessed($parent) or $parent->{lazy};
}

sub first_parent {
    my ($self, $type) = @_;
    return $self if $self->is_type($type);
    my $parent = $self->{parent} or return;
    return $parent->first_parent($type);
}

sub substr {
    my $self    = shift;
    my $data    = $self->Data;
    my $offset  = shift(@_) - ($self->{size} - length($data));
    my $length  = @_ ? shift(@_) : (length($data) - $offset);
    my $replace = shift;

    # XXX - Check for "substr outside string"
    return if $offset > length($data);

    # Fetch a range
    return substr($data, $offset, $length) if !defined $replace;

    # Substitute a range
    substr($data, $offset, $length, $replace);
    $self->{struct}{Data} = $data;
}

sub set_output_file {
    my ($self, $file) = @_;

    open my $fh, '>', $file or die $!;
    binmode($fh);
    $self->{output} = $fh;
}

my %callback_map;
sub callback {
    my $self  = shift;
    my $pkg   = shift || caller;
    my $types = shift or return;

    my $map = $callback_map{"@$types"} ||= $self->callback_map($pkg, $types);
    my $sub = $map->{ref $self} || $map->{'*'} or return;
    unshift @_, $self;
    goto &$sub;
}

sub callback_map {
    my ($self, $pkg, $types) = @_;
    my %map;
    my $base = $self->BASE_CLASS;
    foreach my $type (map "$_", @$types) {
	no strict 'refs';
	my $method = $type;
	$method =~ s/::/_/g;
	$method =~ s/\*/__/g;

	defined &{"$pkg\::$method"} or next;

	$type = "$base\::$type" unless $type eq '*';
	$map{$type} = \&{"$pkg\::$method"};
    }
    return \%map;
}

sub callback_members {
    my $self = shift;
    $self->{callback_members} = { map { ($_ => 1) } @{$_[0]} };

    while (my $member = $self->next_member) {
	$member->callback(scalar caller, @_);
    }
}

sub done {
    my $self = shift;
    return unless $self->{lazy};
    $self->write;
    $self->remove;
}

1;

__END__

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2004-2009 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
