use inc::Module::Install;
name 'Kagura';
all_from 'lib/Kagura.pm';

requires 'Path::Class', 0.23;
requires 'Plack', 0.99;
requires 'Tiffany', 0.03;
requires 'Encode', 2.39;
requires 'Object::Container', 0.14;
requires 'Router::Simple::Sinatraish', 0.02;
requires 'Class::Data::Inheritable', 0.08;

test_requires 'Test::More', 0.96;

tests join q{ }, map { sprintf 't%s.t', '/*' x $_ } 1..3;
author_tests 'xt';

auto_set_repository();

WriteAll;
