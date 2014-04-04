#!perl

use strict;
use warnings;

use Test::More;
use Test::Directory;

use ExtUtils::BundleMaker;

my $dir = Test::Directory->new("t/inc");
my $bm = ExtUtils::BundleMaker->new( module => "ExtUtils::BundleMaker", includes => [] );
$bm->make_bundle( "t/inc" );

$dir->has("eu-bm.inc");

done_testing();
