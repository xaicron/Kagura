use inc::Module::Install;
use Module::Install::ReadmePodFromPod;

name 'Kagura';
all_from 'lib/Kagura.pm';
readme_pod_from  'lib/Kagura.pm';

requires 'Path::Class', 0.23;
requires 'Plack', 0.99;
requires 'Tiffany', 0.03;
requires 'Encode', 2.39;
requires 'Router::Simple::Sinatraish', 0.02;
requires 'Class::Data::Inheritable', 0.08;
requires 'Text::MicroTemplate', 0.18;
requires 'Class::Accessor::Lite', 0.05;
requires 'Object::Container', 0.14;

recommends 'JSON', 2.50;
recommends 'Log::Dispatch', 2.27;
recommends 'Text::Xslate', 1.0000;

test_requires 'Test::More', 0.96;

tests join q{ }, map { sprintf 't%s.t', '/*' x $_ } 1..3;
author_tests 'xt';

install_script 'script/kagura-setup.pl';
no_index directory => 'eg';

auto_set_repository();

WriteAll;
