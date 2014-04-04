use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
                                  module_name       => 'ExtUtils::BundleMaker',
                                  license           => 'Perl_5',
                                  dist_author       => q{Jens Rehsack <rehsack@cpan.org>},
                                  dist_version_from => 'lib/ExtUtils/BundleMaker.pm',
                                  build_requires    => {
                                                      'Test::More' => '0.90',
                                                    },
                                  requires => {
                                                'File::Slurp'     => 0,
                                                'Moo'             => 0,
                                                'MooX::Options'   => '4.000',
                                                'Module::Runtime' => 0,
                                              },
                                  add_to_cleanup => ['ExtUtils-BundleMaker-*'],
                                  meta_merge     => {
                                                  'meta-spec' => { version => 2 },
                                                  resources   => {
                                                                 repository => {
                                                                       url => 'git://github.com/rehsack/ExtUtils-BundleMaker.git',
                                                                       web => 'https://github.com/rehsack/ExtUtils-BundleMaker',
                                                                       type => 'git',
                                                                 },
                                                               },
                                                  prereqs => {
                                                               develop => {
                                                                            requires => {
                                                                                       'Test::CPAN::Changes'                 => 0,
                                                                                       'Test::CheckManifest'                 => 0,
                                                                                       'Test::Pod'                           => 0,
                                                                                       'Test::Pod::Coverage'                 => 0,
                                                                                       'Test::Pod::Spelling::CommonMistakes' => 0,
                                                                            },
                                                                          },
                                                               runtime => {
                                                                            suggests => {
                                                                                          'MetaCPAN::API' => 0,
                                                                                        },
                                                                          },
                                                             },
                                                },
                                  create_readme => 1,
                                  test_files    => join( ' ' => 't/*.t xt/*.t' ),
                                );

$builder->create_build_script();
