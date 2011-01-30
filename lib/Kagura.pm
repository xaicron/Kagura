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
    ro  => [qw/req params/],
    rw  => [qw/stash/],
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
    $class->mk_classdata('renderer');
    $class->mk_classdata('container', 'Object::Container');
    $class->mk_classdata('response_class', 'Plack::Response');
    $class->mk_classdata('request_class', 'Plack::Request');

    $class->init_home_dir();
    $class->init_config();
    $class->init_renderer();
    $class->init_container();
    $class->init_plugins();

    $class->init_prepare();
}

# you can override this method
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
    return $_[0]->response_class->new(404, [], ['404 Not Found']);
}

sub return_403 {
    return $_[0]->response_class->new(403, [], ['403 Forbidden']);
}

sub show_error {
    my ($self, $msg) = @_;
    return $self->response_class->new(500,
        ['Content-Type' => 'text/html; charset=utf-8'],
        [$msg || '500 Internal Server Error'],
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
        if (my ($match, $route) = $class->router->routematch($env)) {
            delete $match->{code} if ref $match->{code} eq 'CODE';

            my $req = $pkg->request_class->new($env);
            my $c = $pkg->new(
                req    => $req,
                class  => $class,
                stash  => {},
                params => +{ %$match },
            );
            no strict 'refs';
            local *{"$pkg\::context"} = sub { $c };
            use strict 'refs';

            my $res = $route->{dest}{code}->($c, $req);
            $res = $c->show_error() unless ref $res;
            return $res->finalize;
        }
        else {
            return $pkg->return_404();
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

Generating new project:

  $ kagura-setup.pl MyApp

run app.psgi

  $ cd MyApp
  $ plackup MyApp.psgi

=head1 DESCRIPTION

Kagura is easy, simple, lightweight web application framework.

=head1 EXPORT FUNCTIONS

=over 4

=item B<< get($path, $code) >>

=item B<< post($path, $code) >>

=item B<< any([$method, ] $path, $code) >>

This functions from L<< Router::Simple::Sinatraish >>.

C<< $code >> must be returned Plack::Response-like object.

  pacakge MyApp;
  use MyApp::Web;
  
  get '/' => sub {
      my ($c, $req) = @_;
      ...
      my $res = $c->response_class->new(200, [], ['Hello Kagura!!']);
      return $res;
  }
  post '/' => sub {
      my ($c, $req) = @_;
      ...
      return $res;
  }
  any '/' => sub {
      my ($c, $req) = @_;
      ...
      return $res;
  }
  any [qw/GET DELETE/], '/any' => sub {
      my ($c, $req) = @_;
      ...
  }
  
  # $c   is Kagura-like object
  # $req is Plack::Requst-like object (eq $c->req)
  # $res is Plack::Response-like object

=item B<< dispatch($contoroller, $method_name) >>

Sets dispatch rule.

into MyApp.pm

  pacakge MyApp;
  use MyApp::Web;
  
  # call MyApp::Web::C::Root::index
  get '/' => dispatch('Root', 'index');

into MyApp/Web/C/Root.pm

  package MyApp::Web::C::Root;
  
  sub index {
      my ($c, $req) = @_;
      ...
  }

=back

=head1 METHOD

=over 4

=item B<< req() >>

Get request object.

  get '/' => sub {
     my ($c, $req) = @_;
     $c->req; # eq $req
     ...
  }

=item B<< params() >>

Route parameters.

  get '/{user}' => sub {
     my ($c, $req) = @_;
     my $params = $c->params;
     ...
  }
  
  # GET http://localhost/foo
  # $params->{user} eq 'foo'

=item B<< render(@args) >>

Rendering template. Returned C<< response_class >> object.

  get '/' => sub {
     my ($c, $req) = @_;
     ...
     my $res = $c->render('index.mt');
     return $res;
  }

=item B<< model($name) >>

Get C<< MyApp::M::$name >> object.

  pacakge MyApp::M::User;
  sub find {
      my ($self, $user_id) = @_;
      ...
      return $user_name;
  }
  
  package MyApp;
  use parent 'MyApp::Web';
  get '/{user_id}' => sub {
      my ($c, $req) = @_;
      my $user_name = $c->model('User')->find($c->params->{user_id});
      ...
  }

=item B<< return_404() >>

Returned status 404.

  get '/404' => sub {
     my ($c, $req) = @_;
     return $c->return_404();
  }

=item B<< return_403() >>

Returned status 403.

  get '/403' => sub {
     my ($c, $req) = @_;
     return $c->return_403();
  }

=item B<< show_error() >>

Returned status 500.

  get '/error' => sub {
     my ($c, $req) = @_;
     return $c->show_error('oops!!');
  }

=item B<< stash([$hashref]) >>

You can use freely.

=back

=head1 CLASS METHOD

=over 4

=item B<< to_app() >>

into app.psgi

  use MyApp;
  MyApp->to_app;

=item B<< init() >>

Initialize application. This method in to_app() called.

=item B<< init_prepare() >>

Call prepare init() method. This method is in inii() called.

You can override this method.

  pacakge MyApp::Web;
  use parent 'Kagura';
  
  sub init_prepare {
      my ($class) = @_;
      ...
  }

=item B<< init_finalize() >>

Call finalize init() method. This method is in inii() called.

You can override this method.

  pacakge MyApp::Web;
  use parent 'Kagura';
  
  sub init_finalize {
      my ($class) = @_;
      ...
  }

=item B<< load_plugin($class [, $config]) >>

Load plugin class. this method must be calling in init_finalzie() or after init().

  package MyApp::Web;
  use parent 'Kagura'
  
  sub init_finalize {
      my ($class) = @_;
      $class->load_plugin('Web::JSON');
      $class->load_plugin('+MyApp::Plugin::Foo', +{ bar => 'baz' });
  }

=item B<< load_plugins(%args) >>

Load plugins.

  package MyApp::Web;
  use parent 'Kagura';
  
  sub init_finalize {
      my ($class) = @_;
      $class->load_plugins(
        'Web::JSON'           => {},
        '+MyApp::Plugin::Foo' => +{ bar => 'baz' }
      );
  }

or configuration:

  # conf/developlemt.pl
  +{
      plugin => +{
          'Web::JSON'           => +{},
          '+MyApp::Plugin::Foo' => +{ bar => 'baz' },
      },
  }

=back

=head1 DEFAULT CLASS ACCESSOR METHOD

These methods you can calling the after init().

=over 4

=item B<< config([$hash_ref]) >>

Loaded configuration from C<< conf/$ENV{PLACK_ENV}.pl >>

=item B<< home_dir([$home_dir]) >>

Sets value must be L<< Path::Class >>-like object.

=item B<< renderer([$renderer]) >>

Sets value must be L<< Tiffany >>::* object.

=item B<< container([$scalar] >>

Default 'Object::Container'

=item B<< request_class([$scalar]) >>

Default 'Plack::Request'

=item B<< response_class([$scalar]) >>

Default 'Plack::Response'

=back

=head1 AUTHOR

xaicron E<lt>xaicron {at} cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
