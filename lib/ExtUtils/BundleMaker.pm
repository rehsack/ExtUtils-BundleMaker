package ExtUtils::BundleMaker;

use strict;
use warnings FATAL => 'all';

use Moo;
use MooX::Options;
use Module::Runtime qw/use_module module_notional_filename/;
use File::Slurp qw/read_file write_file/;
use File::Spec;

=head1 NAME

ExtUtils::BundleMaker - Supports making bundles of modules

=cut

our $VERSION = '0.001';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use ExtUtils::BundleMaker;

    my $eu_bm = ExtUtils::BundleMaker->new(
        module => 'Important::One',
	# can be omitted when MetaCPAN is availble
	includes => [ 'Important::One::Util', 'Important::One::Sugar' ]
	# can be omitted when prerequisites are appropriate
	also => {
	    module => 'Significant::Dependency',
	},
    );
    # create inc/important_one.inc
    $eu_bm->make_bundle( output => 'inc' );

=head1 ATTRIBUTES

Following attributes are supported by ExtUtils::BundleMaker

=head2 module

Specifies name of module to create bundle for

=head2 includes

Specifies list of modules to be included in bundle

=head2 also

Specifies list of more bundles to include (recursively)

=head1 METHODS

=cut

option module => (
                   is       => "ro",
                   doc      => "Specifies name of module to create bundle for",
                   required => 1,
                 );

option includes => (
                     is        => "lazy",
                     doc       => "Specifies list of modules to be included in bundle",
                     format    => "s@",
                     autosplit => ",",
                   );

sub _build_includes
{
    my $self = shift;
    defined $INC{"MetaCPAN/API.pm"} or require 'MetaCPAN/API.pm';
    my $mcpan = MetaCPAN::API->new();
    my $mod = $mcpan->module($self->module);
    my $dist = $mcpan->release( distribution => $mod->{distribution} );
    return [ @{$dist->{provides}} ];
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

    my @modules = ($self->module, @{$self->includes});

    eval "use " . $self->module . ";";
    $@ and die $self->module . " is not available: $@";

    my $body = sprintf <<'EOU', $self->module, $self->module->VERSION;
check_module("%s", "%s") or eval <<'END_OF_EXTUTILS_BUNDLE_MAKER_MARKER';
EOU

    foreach my $mod (@modules)
    {
	my $mnf = module_notional_filename(use_module( $self->module ));
	$body .= read_file($INC{$mnf});
	$body .= "\n";
    }

    $body .= "\nEND_OF_EXTUTILS_BUNDLE_MAKER_MARKER\n";

    return $body;
}

=head2 make_bundle

=cut

sub make_bundle
{
    my ( $self, $target ) = @_;

    my $body = $self->_bundle_body_stub . $self->_bundle_body;
    foreach my $also ( @{ $self->also } )
    {
        $body .= "\n" . $also->_bundle_body;
    }
    $body .= "\n1;\n";

    my $modname_s = $self->module;
    $modname_s =~ s/[^A-Z:]//g;
    $modname_s =~ s/:+/-/g;
    $modname_s =~ tr/A-Z/a-z/;

    my $fn = File::Spec->catfile( $target, $modname_s . ".inc" );
    return write_file( $fn, $body );
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
