package Kagura::Util;

use strict;
use warnings;
use Plack::Util ();
use Exporter 'import';

our @EXPORT      = ();
our @EXPORT_OK   = qw(add_method load_class);
our %EXPORT_TAGS = (
    all => [@EXPORT, @EXPORT_OK],
);

sub add_method {
    my ($klass, $name, $code) = @_;
    no strict 'refs';
    *{"$klass\::$name"} = $code;
}

sub load_class {
    Plack::Util::load_class(@_);
}

1;
__END__
