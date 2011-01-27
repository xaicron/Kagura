use strict;
use warnings;
use Test::More;
use Kagura;

can_ok main => qw(
    get post any
    init dispatch to_app
);

done_testing;
