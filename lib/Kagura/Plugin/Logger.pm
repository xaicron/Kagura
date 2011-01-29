package Kagura::Plugin::Logger;

use strict;
use warnings;
use Kagura::Util;

sub init {
    my ($class, $c, $conf) = @_;
    $conf ||= $c->config->{logger} || {};

    my $logger_class = $conf->{class} || 'Log::Dispatch';
    my $args         = $conf->{args}  || [];
    my $logger = Plack::Util::load_class($logger_class)->new(@$args);

    $c->mk_classdata('logger');
    $c->logger($logger);
    Kagura::Util::add_method($c, log => sub { $logger });
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
  
  __PACKAGE__->load_plugin('Logger');
  
  # in your config.pl
  logger => +{
      class => 'Log::Dispatch', # default
      args  => [
          outputs => [
              'Screen' => (
                  min_level => 'debug',
                  stderr    => 1,
                  newline   => 1,
              ),
          ],
      ],
  },
  
  # in your controller
  $c->log->debug('foo bar');

=head1 DESCRIPTION

Kagura::Plugin::Logger is sets logger class for Kagura.

Any logger class can be set by configuration.

=head1 AUTHOR

xaicron E<lt>xaicron {at} cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
