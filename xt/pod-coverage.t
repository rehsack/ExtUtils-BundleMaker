#! perl

use strict;
use warnings;

use Test::More;
use Test::Pod::Coverage;

all_pod_coverage_ok( { trustme => [qr/^BUILDARGS$/, qr/^has_.*/], } );
