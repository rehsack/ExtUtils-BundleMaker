use strict;
use warnings FATAL => 'all';
use Module::Build;

# maybe after some patching of MetaCPAN::Client that's reintroduced
# recommends => {
#     'CHI'                    => 0,
#     'HTTP::Tiny::Mech'       => 0,
#     'WWW::Mechanize::Cached' => 0,
# },

my $builder = Module::Build->new(
    module_name       => 'ExtUtils::BundleMaker',
    dist_author       => q{Jens Rehsack <rehsack@cpan.org>},
    dist_version_from => 'lib/ExtUtils/BundleMaker.pm',
    add_to_cleanup    => ['ExtUtils-BundleMaker-*'],
    meta_merge        => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                url  => 'git://github.com/rehsack/ExtUtils-BundleMaker.git',
                web  => 'https://github.com/rehsack/ExtUtils-BundleMaker',
                type => 'git',
            },
            license    => ['http://dev.perl.org/licenses/'],
            bugtracker => {
                web    => 'http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ExtUtils-BundleMaker',
                mailto => 'bug-extutils-bundlemaker@rt.cpan.org',
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
                requires => {
                    'File::Basename'       => 0,
                    'File::Path'           => 0,
                    'File::Slurp'          => 0,
                    'File::Spec'           => 0,
                    'MetaCPAN::Client'     => 0,
                    'Moo'                  => 0,
                    'MooX::Options'        => '4.000',
                    'MooX::ConfigFromFile' => 0,
                    'Module::CoreList'     => '2.99',
                    'Module::Runtime'      => 0,
                    'Params::Util'         => 0,
                    'version'              => 0,
                },
            },
            build => {
                requires => {
                    'Test::More'          => '0.90',
                    'Test::WriteVariants' => '0.005',
                },
            },
        },
    },
    create_readme => 1,
    test_files    => join( ' ' => 't/*.t xt/*.t' ),
);

$builder->create_build_script();
