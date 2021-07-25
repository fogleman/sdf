package Module::ScanDeps::Cache;
use strict;
use warnings;
my $has_DMD5;
eval { require Digest::MD5 };
$has_DMD5 = 1 unless $@;
my $has_Storable;
eval { require Storable };
$has_Storable = 1 unless $@;


my $cache;
my $cache_file;
my $cache_dirty;

sub prereq_missing{
    my @missing;
    push @missing, 'Digest::MD5' unless $has_DMD5;
    push @missing, 'Storable'    unless $has_Storable;
    return @missing;
}

sub init_from_file{
    my $c_file = shift;
    return 0 if prereq_missing();
    eval{$cache = Storable::retrieve($c_file)};
    #warn $@ if ($@);
    unless ($cache){
        warn "Couldn't retrieve data from file $c_file. Building new cache.\n";
        $cache = {};
    }
    $cache_file = $c_file;
    return 1;
}

sub store_cache{
    my $c_file = shift || $cache_file;
    # no need to store to the file we retrieved from
    # unless we have seen changes written to the cache
    return unless ($cache_dirty
                   || $c_file ne $cache_file);
    Storable::nstore($cache, $c_file)
          or warn "Could not store cache to file $c_file!";
}

sub get_cache_cb{
    return sub{
        my %args = @_;
        if ( $args{action} eq 'read' ){
            return _read_cache( %args );
        }
        elsif ( $args{action} eq 'write' ){
            return _write_cache( %args );
        }
        die "action in cache_cb must be read or write!";
    };
}

### check for existence of the entry
### check for identity of the file
### pass cached value in $mod_aref
### return true in case of a hit

sub _read_cache{
    my %args = @_;
    my ($key, $file, $mod_aref) = @args{qw/key file modules/};
    return 0 unless (exists $cache->{$key});
    my $entry = $cache->{$key};
    my $checksum = _file_2_md5($file);
    if ($entry->{checksum} eq $checksum){
        @$mod_aref = @{$entry->{modules}};
        return 1;
    }
    return 0;
}

sub _write_cache{
    my %args = @_;
    my ($key, $file, $mod_aref) = @args{qw/key file modules/};
    my $entry = $cache->{$key} ||= {};
    my $checksum = _file_2_md5($file);
    $entry->{checksum} = $checksum;
    $entry->{modules} = [@$mod_aref];
    $cache_dirty = 1;
    return 1;
}

sub _file_2_md5{
    my $file = shift;
    open my $fh, '<', $file or die "can't open $file: $!";
    my $md5 = Digest::MD5->new;
    $md5->addfile($fh);
    close $fh or die "can't close $file: $!";
    return $md5->hexdigest;
}
1;

