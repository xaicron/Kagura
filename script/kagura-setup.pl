#!perl

use strict;
use warnings;
use Text::MicroTemplate qw(render_mt);
use Getopt::Long qw(GetOptions);
use File::Path qw/mkpath/;
use File::Basename qw/dirname/;
use File::Spec;
use Kagura ();

my $renderer = 'Text::MictoTemplate::File';
my $suffix_map = +{
    'Text::MictoTemplate::File' => 'mt',
    'Text::Xslate'              => 'xt',
};

GetOptions(
    'h|help!'             => sub { usage() },
    'r|renderer=s'        => \$renderer,
    's|template-suffix=s' => \my $suffix,
    'p|plugin=s@'         => \my @plugins,
) or usage();

my $name = shift || usage();
(my $base_dir  = $name) =~ s{::}{-}g;
(my $base_path = $name) =~ s{::}{/}g;

main: {
    die "$base_dir is exists!\n" if -e $base_dir;
    mkdir $base_dir or die "$base_dir: $!";
    chdir $base_dir or die "$base_dir: $!";

    write_all();
    exit;
}

sub write_all {
    my $data = _parse_data_section();

    print "Generating for $name\n";
    for my $path (sort keys %$data) {
        my $dir = dirname($path);
        unless (-e $dir) {
            mkpath($dir) or die "Cannot mkpath '$dir': $!";
        }

        print "writing $path\n";
        my $content = $data->{$path};
#        if ($path =~ /\.(?:ico|jpe?g|png|gif)$/) {
#            $content = MIME::Base64::Perl::decode_base64($content);
#        }
        open my $out, '>', $path or die "Cannot open '$path' for writing: $!";
        print $out $content;
        close $out;
    }
}

sub _parse_data_section {
    my $data_string = render_mt(do { local $/; <DATA> }, +{
        kagura_version => $Kagura::VERSION,
        name           => $name,
        base_dir       => $base_dir,
        base_path      => $base_path,
        renderer       => $renderer,
        suffix         => $suffix || $suffix_map->{$renderer} || 'mt',
        plugins        => [@plugins],
    });

    my ($data, $path);
    for my $line (split /\n/, $data_string) {
        if ($line =~ /^\@\@/) {
            ($path) = $line =~ /^\@\@ (.*)/;
            next;
        }
        next unless $path;
        $data->{$path} .= "$line\n";
    }
    return $data;
}

sub usage {
    print << 'USAGE';
Usage: kagura-setup.pl [options] MyApp

Options:
    h, help         show this message
    r, renderer     set rederer class (e.g. Text::Xslate. default Text::MicroTemplate)
    suffix          set template suffix (e.g. tt. default is renderer default suffix)
    p, plugin       sets using plugin(s)

USAGE
    exit 1;
}

=pod

=encoding utf-8

=for stopwords

=head1 NAME

kagura-setup.pl - skeleton generator for Kagura

=head1 SYNOPSIS

  $ kagura-setup.pl MyApp

=head1 AUTHOR

xaicron

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
? my ($params) = @_;
? my $kagura_version = $params->{kagura_version} || 0.01;
? my $name           = $params->{name};
? my $base_dir       = $params->{base_dir};
? my $base_path      = $params->{base_path};
? my $renderer       = $params->{renderer};
? my $suffix         = $params->{suffix};
? my $plugins        = $params->{plugins};

@@ <?= $base_dir ?>.psgi
use lib 'lib';
use <?= $name ?>;
use Plack::Builder;

my $app = <?= $name ?>->to_app;
builder {
    enable 'Static',
        path => qr{^/static|^/favicon.ico$},
        root => './htdocs';
    $app;
};

@@ conf/development.pl
+{
};

@@ lib/<?= $base_path ?>.pm
package <?= $name ?>;
use strict;
use warnings;
use <?= $name ?>::Web;
our $VERSION = '0.01';

get '/' => dispatch(Root => 'index');

1;

@@ lib/<?= $base_path ?>/Web.pm
package <?= $name ?>::Web;

use strict;
use warnings;
use parent 'Kagura';

? if ($renderer eq 'Text::Xslate') {
sub init_renderer {
    my ($class) = @_;

    my $config    = $class->config->{template};
    my $path      = $class->home_dir->subdir($config->{path} || 'tmpl');
    my $cache_dir = $path->subdir($config->{cache_dir} || 'cache');

    my $renderer = Tiffany->load('Text::Xslate', {
        syntax    => $config->{syntax} || 'TTerse',
        path      => $path->stringify,
        module    => [ @{ $config->{module} || [] } ],
        cache     => $config->{cache} || 1,
        cache_dir => $cache_dir->stringify,
    });
    $class->renderer($renderer);
}

? }

1;

@@ lib/<?= $base_path ?>/Web/C/Root.pm
package <?= $name ?>::Web::C::Root;

use strict;
use warnings;

sub index {
    my ($c, $req, $route) = @_;
    $c->render('index.<?= $suffix ?>');
};

1;

@@ lib/<?= $base_path ?>/M.pm
package <?= $name ?>::M;

use strict;
use warnings;

1;

@@ t/00_complie.t
use strict;
use warnings;
use Test::More tests => 1;

BEGIN { use_ok '<?= $name ?>' }

@@ xt/01_podspell.t
use strict;
use warnings;
use Test::More;
use Test::Requires 'Test::Spelling';
use Config;
use File::Spec;
use ExtUtils::MakeMaker;

my %cmd_map = (
    spell  => 'spell',
    aspell => 'aspell list',
    ispell => 'ispell -l',
);

my $spell_cmd;
for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
    next if $dir eq '';
    ($spell_cmd) = map { $cmd_map{$_} } grep {
        my $abs = File::Spec->catfile($dir, $_);
        -x $abs or MM->maybe_command($abs);
    } keys %cmd_map;
    last if $spell_cmd;
}
$spell_cmd = $ENV{SPELL_CMD} if $ENV{SPELL_CMD};
plan skip_all => "spell command are not available." unless $spell_cmd;
add_stopwords(map { split /[\s\:\-]/ } <DATA>);
set_spell_cmd($spell_cmd);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');

__DATA__
<?= $name ?>

@@ xt/02_pod.t
use strict;
use warnings;
use Test::More;

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

all_pod_files_ok();

@@ xt/03_perlcritic
use strict;
use warnings;
use Test::More;

unless ($ENV{TEST_PERLCRITIC}) {
    plan skip_all => "\$ENV{TEST_PERLCRITIC} is not set.";
    exit;
}

eval {
    require Test::Perl::Critic;
    Test::Perl::Critic->import( -profile => 'xt/perlcriticrc');
};
plan skip_all => "Test::Perl::Critic is not installed." if $@;

all_critic_ok('lib');

@@ xt/perlcriticrc
[TestingAndDebugging::ProhibitNoStrict]
allow=refs
[-Subroutines::ProhibitSubroutinePrototypes]

@@ Makefile.PL
use inc::Module::Install;
name '<?= $base_dir ?>';
all_from 'lib/<?= $base_path ?>.pm';

requires 'Kagura', '<?= $kagura_version ?>';
? if ($renderer eq 'Text::Xslate') {
requires 'Text::Xslate', 1.0000;
? }

test_requires 'Test::More', 0.96;
test_requires 'Test::Requires', 0.06;

tests join q{ }, map { sprintf 't%s.t', '/*' x $_ } 1..3;
author_tests 'xt';

WriteAll;

@@ MANIFEST.SKIP
\bRCS\b
\bCVS\b
\.svn/
\.git/
^MANIFEST\.
^Makefile$
~$
\.old$
^blib/
^pm_to_blib
^MakeMaker-\d
\.gz$
\.shipit
\.gitignore
\ppport.h

@@ Changes
Revision history for Perl extension <?= $name ?>

0.01  <?= scalar localtime ?>
    - original version

@@ README
Generated by kagura-setup.pl ($Kagura::VERSION <?= $kagura_version ?>).

You can running this project are:
$ plackup <?= $base_dir ?>.psgi

enjoy!

@@ .shipit
steps = FindVersion, ChangeVersion, CheckChangeLog, DistTest, Commit, Tag, MakeDist, UploadCPAN
git.push_to = origin

@@ .gitignore
cover_db
META.yml
Makefile
blib
inc
pm_to_blib
MANIFEST
Makefile.old
nytprof*
ppport.h
xs/*c
xs/*o
xs/*obj
*.bs
*.def
*.old
dll*
*~

@@ tmpl/index.<?= $suffix ?>
<html>
<head>
    <title>Hello, <?= $name ?></title>
</head>
<body>
    <h1>Hello, <?= $name ?>!!</h1>
    <ul>
        <li>
            Renderer
            <ul>
                <li><?= $renderer ?></li>
            </ul>
        </li>
        <li>
            Template Suffix
            <ul>
                <li><?= $suffix ?></li>
            </ul>
        </li>
? if (@$plugins) {
        <li>
            Plugins
            <ul>
?   for my $plugin (@$plugins) {
                <li><?= $plugin ?></li>
?   }
            </ul>
        </li>
? }
    </ul>
    <p>$Kagura::VERSION: <?= $kagura_version ?>
</body>
</html>

