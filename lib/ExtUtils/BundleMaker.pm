package ExtUtils::BundleMaker;

use strict;
use warnings FATAL => 'all';
use version;

use Moo;
use MooX::Options with_config_from_file => 1;
use Module::CoreList ();
use Module::Runtime qw/require_module use_module module_notional_filename/;
use File::Basename qw/dirname/;
use File::Path qw//;
use File::Slurp qw/read_file write_file/;
use File::Spec qw//;
use Params::Util qw/_HASH _ARRAY/;
use Sub::Quote qw/quote_sub/;

=head1 NAME

ExtUtils::BundleMaker - Supports making bundles of modules

=cut

our $VERSION = '0.001';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use ExtUtils::BundleMaker;

    my $eu_bm = ExtUtils::BundleMaker->new(
        modules => [ 'Important::One', 'Mandatory::Dependency' ],
	# can be omitted when prerequisites are appropriate
	also => {
	    modules => [ 'Significant::Dependency' ],
	},
	# down to which perl version core modules shall be included?
	recurse => 'v5.10',
    );
    # create bundle
    $eu_bm->make_bundle( 'inc/foo_bundle.pl' );

=head1 ATTRIBUTES

Following attributes are supported by ExtUtils::BundleMaker

=head2 modules

Specifies name of module(s) to create bundle for

=head2 also

Specifies list of more bundles to include (recursively)

=head2 target

Specifies target for bundle

=head1 METHODS

=cut

sub _coerce_modules
{
    my $modules = shift;
    _HASH($modules)  and return $modules;
    _ARRAY($modules) and return {
        map {
            my ( $m, $v ) = split( /=/, $_, 2 );
            defined $v or $v = 0;
            ( $m => $v )
        } @$modules
    };
    die "Inappropriate format: $modules";
}

option modules => (
    is        => "ro",
    doc       => "Specifies name of module(s) to create bundle for",
    required  => 1,
    format    => "s@",
    autosplit => ",",
    coerce    => \&_coerce_modules,
);

option recurse => (
    is       => "lazy",
    doc      => "Automatically bundles dependencies for specified Perl version",
    required => 1,
    format   => "s",
    coerce   => quote_sub(q{ version->new($_[0])->numify }),
);

option target => (
    is       => "ro",
    doc      => "Specifies target for bundle",
    required => 1,
    format   => "s"
);

sub _build_recurse
{
    $];
}

has chi_init => ( is => "lazy" );

sub _build_chi_init
{
    my %chi_args = (
        driver   => 'File',
        root_dir => '/tmp/metacpan-cache',
    );
    return \%chi_args;
}

has _meta_cpan => (
    is       => "lazy",
    init_arg => undef,
);

sub _build__meta_cpan
{
    my $self = shift;
    require_module("MetaCPAN::Client");
    my %ua;
    eval {
        require_module("CHI");
        require_module("WWW::Mechanize::Cached");
        require_module("HTTP::Tiny::Mech");
        my $cia = $self->chi_init();
        %ua = (
            ua => HTTP::Tiny::Mech->new(
                mechua => WWW::Mechanize::Cached->new(
                    cache => CHI->new(%$cia),
                ),
            )
        );
    };
    my $mcpan = MetaCPAN::Client->new(%ua);
    return $mcpan;
}

sub _coerce_also
{
    my @also = @_;
    @also or return [];
    1 == @also and ref $also[0] eq "HASH" and return _coerce_also( \@also );
    1 != @also and die "also => [...]";
    ref $also[0] eq "ARRAY" or die "also => [...]";
    @{ $also[0] } = map { ExtUtils::BundleMaker->new( %{$_} ) } @{ $also[0] };
    return $also[0];
}

option also => (
    is        => "ro",
    doc       => "Specifies list of more bundles to include (recursively)",
    format    => "s@",
    autosplit => ",",
    coerce    => \&_coerce_also,
    default   => sub { [] },
);

has requires => (
    is => "lazy",
);

sub _build_requires
{
    my $self     = shift;
    my $core_v   = $self->recurse;
    my $mcpan    = $self->_meta_cpan;
    my %modules  = %{ $self->modules };
    my @required = sort keys %modules;
    my %satisfied;
    my @loaded;

    while (@required)
    {
        my $modname = shift @required;
        $modname eq "perl" and next;    # XXX update $core_v if gt and rerun?
        my $mod  = $mcpan->module($modname);
        my $dist = $mcpan->release( $mod->distribution );
        foreach my $dist_mod ( @{ $dist->provides } )
        {
            $satisfied{$dist_mod} and next;
            my $pmod = $mcpan->module($dist_mod);
            push @loaded, $dist_mod;
            $satisfied{$_} = 1 for ( map { $_->{name} } @{ $pmod->module } );
        }

        my %deps = map { $_->{module} => $_->{version} }
          grep {
                 ( not Module::CoreList::is_core( $_->{module}, $_->{version}, $core_v ) )
              or Module::CoreList::deprecated_in( $_->{module} )
              or Module::CoreList::removed_from( $_->{module} )
          }
          grep { $_->{phase} eq "runtime" and $_->{relationship} eq "requires" } @{ $dist->dependency };
        foreach my $dep ( keys %deps )
        {
            defined $satisfied{$dep} and next;
            push @required, $dep;
            $modules{$dep} = $deps{$dep};
        }
    }

    # update modules for loader ...
    %{ $self->modules } = %modules;

    [ reverse @loaded ];
}

has _bundle_body_stub => ( is => "lazy" );

sub _build__bundle_body_stub
{
    my $_body_stub = <<'EOU';
sub check_module
{
    my ($mod, $ver) = @_;
    my $rc = fork();
    if($rc < 0) {
	die "Need fork(2)";
    }
    elsif($rc) {
	# parent
	waitpid $rc, 0;
	printf("Test for %s: %d\n", $mod, $?);
	return 0 == $?;
    }
    else {
	# child
	eval "use $mod";
	$mod->VERSION($ver) or exit(1);
	exit(0);
    }
}
EOU
    return $_body_stub;
}

has _bundle_body => ( is => "lazy" );

sub _build__bundle_body
{
    my $self = shift;

    my @requires = @{ $self->requires };
    # keep order; requires builder might update modules
    my %modules = %{ $self->modules };
    my $body    = "";

    foreach my $mod (@requires)
    {
        my $mnf  = module_notional_filename( use_module($mod) );
        my $modv = $modules{$mod};
        defined $modv or $modv = 0;
        $body .= sprintf <<'EOU', $mod, $modv;
check_module("%s", "%s") or eval <<'END_OF_EXTUTILS_BUNDLE_MAKER_MARKER';
EOU

        $body .= read_file( $INC{$mnf} );
        $body .= "\nEND_OF_EXTUTILS_BUNDLE_MAKER_MARKER\n\n";
        $body .= sprintf "\$INC{'%s'} = 'Bundled';\n", $mnf;
        # XXX Hash::Merge requirements from meta ...
        $body .= "\n";
    }

    return $body;
}

=head2 make_bundle

=cut

sub make_bundle
{
    my $self   = shift;
    my $target = $self->target;

    my $body = $self->_bundle_body_stub . $self->_bundle_body;
    foreach my $also ( @{ $self->also } )
    {
        $body .= "\n" . $also->_bundle_body;
    }
    $body .= "\n1;\n";

    my $target_dir = dirname($target);
    -d $target_dir or File::Path::make_path($target_dir);

    return write_file( $target, $body );
}

=head1 AUTHOR

Jens Rehsack, C<< <rehsack at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-extutils-bundlemaker at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ExtUtils-BundleMaker>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ExtUtils::BundleMaker

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=ExtUtils-BundleMaker>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/ExtUtils-BundleMaker>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/ExtUtils-BundleMaker>

=item * Search CPAN

L<http://search.cpan.org/dist/ExtUtils-BundleMaker/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Jens Rehsack.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.


=cut

1;    # End of ExtUtils::BundleMaker
