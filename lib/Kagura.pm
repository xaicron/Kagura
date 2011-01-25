package Kagura;

use strict;
use warnings;
use Plack::Request;
use Plack::Response;
use Tiffany;
use Encode ();
use Object::Container ();
use Router::Simple::Sinatraish ();
use Class::Data::Inheritable;
use Path::Class qw(file dir);
use Plack::Util ();

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

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    bless { %args }, $class;
}

sub contenxt { die "no context is awaked" }

sub mk_classdata {
    my $class = shift;
    Class::Data::Inheritable::mk_classdata($class, @_);
}

sub init {
    my ($class) = @_;

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
    $class->response_class('Plack::Response');
    $class->request_class('Plack::Request');
}

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

    my $config    = $class->config->{template};
    my $path      = $class->home_dir->subdir($config->{path} || 'tmpl');
    my $cache_dir = $path->subdir($config->{cache_dir} || 'cache');

    my $renderer = Tiffany->load('Text::Xslate', {
        syntax    => $config->{syntax} || 'TTerse',
        path      => $path->stringify,
        module    => [ 'Text::Xslate::Bridge::TT2Like', @{ $config->{module} || [] } ],
        cache     => $config->{cache} || 1,
        cache_dir => $cache_dir->stringify,
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

sub load_plugin {
    my ($class, $module, $conf) = @_;
    $module = Plack::Util::load_class($module, __PACKAGE__.'::Plugin');
    $module->init($conf);
}

sub load_plugins {
    my ($class, @args)  = @_;
    my $conf = $class->config->{plugin} || {};
    for (my $i = 0; $i < @args; $i+=2) {
        my ($module, $conf) = @args[$i,$i+1];
        $class->load_plugin($module, $conf);
    }
}

sub render {
    my ($self) = shift;
    my $content = Encode::encode_utf8($self->renderer->render(@_));
    $self->response_class->new(200, [
        'Content-Length' => length($content),
        'Content-Type'   => 'text/html; charset=utf-8',
    ], [$content]);
}

sub return_404 {
    return shift->response_class->new(404, [], ['404 not found']);
}

sub return_403 {
    return shift->response_class->new(403, [], ['403 forbidden']);
}

sub show_error {
    my ($self, $msg) = @_;
    return shift->response_class->new(500,
        ['Content-Type' => 'text/html; charset=utf-8'],
        [$msg || ''],
    );
}

sub req {
    $_[0]->{req};
}

sub model {
    my ($self, $model, @args) = @_;
    my $model_class = "$self->{class}::M::$model";
    $self->container->get($model_class);
}

sub params {
    my $self = shift;
    return $self->{params} unless @_;
    $self->{params} = shift;
}

sub to_app {
    my ($class) = shift;

    my $pkg = $class->_class;
    $pkg->init;

    sub {
        my $env = shift;
        my $req = $pkg->request_class->new($env);
        my $c   = $pkg->new(req => $req, class => $class);
        no strict 'refs';
        local *{"$pkg\::context"} = sub { $c };
        use strict 'refs';

        if (my $route = $class->router->match($env)) {
            my $code = delete $route->{code};
            $c->params({ %$route });
            my $res = $code->($c, $req);
            $res->finalize;
        }
        else {
            return [404, [], ['not found']];
        }
    };
}

sub dispatcher {
    my ($class, $route, $method) = @_;
    my $module = Plack::Util::load_class($route, "$class\::C");
    return \&{"$module\::$method"};
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
      my ($c, $req, $route) = @_l
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

Kagura is

=head1 AUTHOR

xaicron E<lt>xaicron {at} cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
