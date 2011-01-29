package Kagura;

use strict;
use warnings;
use Plack::Request;
use Plack::Response;
use Tiffany;
use Encode ();
use Router::Simple::Sinatraish ();
use Class::Data::Inheritable;
use Path::Class qw/file dir/;
use Plack::Util ();
use Object::Container ();
use Class::Accessor::Lite (
    new => 1,
    ro  => [qw/req/],
    rw  => [qw/params stash/],
);

our $VERSION = '0.01';

sub import {
    my ($pkg) = @_;
    my $class = caller(0);

    Router::Simple::Sinatraish->export_to_level(1);

    no strict 'refs';
    *{$class."::to_app"} = \&to_app;
    *{$class."::_class"} = sub { $pkg };
    *{$class."::dispatch"} = sub {
        use strict 'refs';
        dispatch($class, @_);
    };
    *{$class."::init"} = sub {
        use  strict 'refs';
        $pkg->init;
    };
}

sub contenxt { die "no context is awaked" }

sub mk_classdata {
    my $class = shift;
    Class::Data::Inheritable::mk_classdata($class, @_);
}

sub init {
    my ($class) = @_;

    $class->init_prepare();

    $class->mk_classdata('config');
    $class->mk_classdata('home_dir');
    $class->mk_classdata('response_class');
    $class->mk_classdata('request_class');
    $class->mk_classdata('renderer');
    $class->mk_classdata('container');

    $class->init_home_dir();
    $class->init_config();
    $class->init_renderer();
    $class->init_container();
    $class->init_plugins();
    $class->response_class('Plack::Response');
    $class->request_class('Plack::Request');

    $class->init_prepare();
}

# you can overwride this method
sub init_prepare  {}
sub init_finalize {}

sub init_home_dir {
    my ($class) = @_;
    my $home_dir = dir($ENV{KAGURA_HOME} || '.');
    $class->home_dir($home_dir);
}

sub init_config {
    my ($class) = @_;
    my $env    = $ENV{PLACK_ENV} || 'development';
    my $fname  = $class->home_dir->file('conf', "$env.pl")->stringify;
    my $config = do $fname or die "cannot load configuration file: $fname";
    $class->config($config);
}

sub init_renderer {
    my ($class) = @_;

    my $config = $class->config->{template};
    my $path   = do {
        my $path = $config->{path} || ['tmpl'];
        $path = [ $path ] unless ref $path eq 'ARRAY';
        $path;
    };

    my $renderer = Tiffany->load('Text::MicroTemplate::File', {
        include_path => [ map { $class->home_dir->subdir($_)->stringify } @$path ],
        use_cache    => $config->{use_cache},
    });

    $class->renderer($renderer);
}

sub init_container {
    my ($class) = @_;
    $class->container('Object::Container');
    return unless $class->config->{container};

    my $container = $class->config->{container};
    for my $name (keys %$container) {
        $class->container->register({
            class       => $name,
            initializer => $container->{$name}{init},
            args        => $container->{$name}{args},
            preload     => $container->{$name}{preload},
        });
    }
}

sub init_plugins {
    my ($class) = @_;
    my $config = $class->config->{plugin} || {};
    $class->load_plugins(%$config);
}

sub load_plugins {
    my ($class, %args)  = @_;
    for my $module (keys %args) {
        my $conf = $args{$module};
        $class->load_plugin($module, $conf);
    }
}

sub load_plugin {
    my ($class, $module, $conf) = @_;
    $module = Plack::Util::load_class($module, __PACKAGE__.'::Plugin');
    $module->init($class, $conf);
}

sub render {
    my $self = shift;
    my $content = Encode::encode_utf8($self->renderer->render(@_));
    $self->response_class->new(200, [
        'Content-Length' => length($content),
        'Content-Type'   => 'text/html; charset=utf-8',
    ], [$content]);
}

sub return_404 {
    return $_[0]->response_class->new(404, [], ['404 not found']);
}

sub return_403 {
    return $_[0]->response_class->new(403, [], ['403 forbidden']);
}

sub show_error {
    my ($self, $msg) = @_;
    return $self->response_class->new(500,
        ['Content-Type' => 'text/html; charset=utf-8'],
        [$msg || ''],
    );
}

sub model {
    my ($self, $model) = @_;
    my $model_class = "$self->{class}::M::$model";
    $self->container->get($model_class);
}

sub dispatch {
    my ($class, $route, $method) = @_;
    my $module = Plack::Util::load_class($route, "$class\::Web::C");
    return \&{"$module\::$method"};
}

sub to_app {
    my ($class) = shift;

    my $pkg = $class->_class;
    $pkg->init;

    sub {
        my $env = shift;
        my $req = $pkg->request_class->new($env);
        my $c   = $pkg->new(req => $req, class => $class, stash => {});
        no strict 'refs';
        local *{"$pkg\::context"} = sub { $c };
        use strict 'refs';

        if (my $route = $class->router->match($env)) {
            my $code = delete $route->{code};
            $c->params({ %$route });
            my $res = $code->($c, $req);
            return $res->finalize;
        }
        else {
            return [404, [], ['not found']];
        }
    };
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Kagura - simple web application framework

=head1 SYNOPSIS

inside MyApp.pm

  package MyApp;
  use Kagura;
   
  get '/' => sub {
      my ($c, $req, $route) = @_;
      $c->render('index.xt');
  };
   
  get '/foo' => dispach('Foo' => 'bar');
   
  1;

inside app.psgi

  use MyApp;
  MyApp->to_app;

run app.psgi

  $ plackup -Ilib app.psgi

=head1 DESCRIPTION

Kagura is easy, simple, lightweightl web application framework.

=head1 AUTHOR

xaicron E<lt>xaicron {at} cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
