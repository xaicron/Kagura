package Kagura::Plugin::Logger;

use strict;
use warnings;
use Kagura::Util;

sub init {
    my ($class, $c, $conf) = @_;
    $conf ||= $c->config->{plugin}{Logger} || {};

    my $logger;
    my $args = $conf->{args} || [];
    if (my $logger_class = $conf->{class}) {
        $logger = Plack::Util::load_class($logger_class)->new(@$args);
    }
    else {
        $logger = Kagura::Log->new(@$args);
    }

    $c->mk_classdata('logger');
    $c->logger($logger);
    Kagura::Util::add_method($c, log => sub { $logger });
}

# no index
package
    Kagura::Log;

use parent 'Log::Dispatch';
use Data::Dump ();
use POSIX qw(strftime);

BEGIN {
    for my $level (qw{
        debug info notice warn warning err error crit critical alert emerg
    }) {
       my $sub = sub {
            my $self = shift;
            my ($module, $file, $line);
            my $i = 0;
            while (($module, $file, $line) = caller($i++)) {
                last if $module !~ m{^(?:Kagura::Plugin::Log::Dispatch|Log::Dispatch)};
            }
            $self->log(
                level   => $level,
                message => "@_",
                module  => $module,
                file    => $file,
                line    => $line,
            );
       };

       no strict 'refs';
       *{$level} = $sub;
    }
}

sub new {
    my ($class, %args) = @_;
    unless ($args{outputs}) {
        $args{outputs} = [
            [ 'Screen', min_level => 'debug', stderr => 1, newline => 1 ],
        ];
    }
    $class->SUPER::new(%args);
}

sub dump {
    my ($self, @data) = @_;
    $self->debug(Data::Dump::dump(@data));
}

sub _log_to {
    my ($self, %p) = @_;
    $p{pid} = $$;
    if ($p{name} eq 'Syslog') {
        $p{message} = sprintf( '[%s] [%s] %s (file: %s, line: %d, pid: %d)',
            @p{qw/level module message file line pid/} );
    }
    else {
        $p{datetime} = strftime( '%Y-%m-%d %H:%M:%S', localtime );
        $p{message} = sprintf( '[%s] [%s] [%s] %s (file: %s, line: %d, pid: %d)',
            @p{qw/datetime level module message file line pid/} );
    }
    $self->SUPER::_log_to(%p);
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
  plugin => +{
      Logger => +{
          class => 'MyLogger', # default Kagura::Plugin::Log::Dispatch
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
