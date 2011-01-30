package Kagura::Plugin::Web::JSON;

use strict;
use warnings;
use Kagura::Util;
use JSON ();

sub init {
    my ($class, $c, $conf) = @_;
    my $json = JSON->new->utf8(1);
    Kagura::Util::add_method($c, render_json => sub {
        my ($self, $data) = @_;
        my $content = $json->encode($data);
        $self->response_class->new(200, [
            'Content-Length' => length($content),
            'Content-Type'   => 'application/json; charset=utf-8',
        ], [$content]);
    });
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Kagura::Plugin::Logger - sets logger

=head1 SYNOPSIS

  package MyApp;
  use parent qw(Kagura);
  
  __PACKAGE__->load_plugin('Web::JSON');
  
  # in your controller
  $c->render_json(+{ foo => 'bar' });

=head1 AUTHOR

xaicron E<lt>xaicron {at} cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
