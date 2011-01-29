package Kagura::Util;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT      = ();
our @EXPORT_OK   = qw(add_method);
our %EXPORT_TAGS = (
    all => [@EXPORT, @EXPORT_OK],
);

sub add_method {
    my ($klass, $name, $code) = @_;
    no strict 'refs';
    *{"$klass\::$name"} = $code;
}

1;
__END__
