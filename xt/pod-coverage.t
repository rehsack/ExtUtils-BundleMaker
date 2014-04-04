#! perl

use strict;
use warnings;

use Test::More;
use Test::Pod::Coverage;

all_pod_coverage_ok( { trustme => [qr/^execute$/, qr/^template_filename$/, qr/^has_/], } );
