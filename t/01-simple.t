#!perl

use strict;
use warnings;

use Test::More;
use Test::Directory;

use ExtUtils::BundleMaker;

my $dir = Test::Directory->new("t/inc");
my $bm = ExtUtils::BundleMaker->new( modules => ["Test::WriteVariants"], target => "t/inc/t-wv.inc" );
$bm->make_bundle();

$dir->has("t-wv.inc");

done_testing();
