package Plack::Middleware::ETag;

use strict;
use warnings;
use Digest::SHA;
use Plack::Util;
use Plack::Util::Accessor qw( file_etag cache_control);

our $VERSION = '0.02';

use parent qw/Plack::Middleware/;

sub call {
    my $self = shift;
    my $res     = $self->app->(@_);

    $self->response_cb(
        $res,
        sub {
            my $res = shift;
            my $headers = $res->[1];
            return if ( !defined $res->[2] );
            return if ( Plack::Util::header_exists( $headers, 'ETag' ) );

            my $etag;

            if ( Plack::Util::is_real_fh( $res->[2] ) ) {

                my $file_attr = $self->file_etag || [qw/inode mtime size/];
                my @stats = stat $res->[2];
                if ( $stats[9] == time - 1 ) {
                    # if the file was modified less than one second before the request
                    # it may be modified in a near future, so we return a weak etag
                    $etag = "W/";
                }
                if ( grep {/inode/} @$file_attr ) {
                    $etag .= (sprintf "%x", $stats[2]);
                }
                if ( grep {/mtime/} @$file_attr ) {
                    $etag .= "-" if ($etag && $etag !~ /-$/);
                    $etag .= ( sprintf "%x", $stats[9] );
                }
                if ( grep {/size/} @$file_attr ) {
                    $etag .= "-" if ($etag && $etag !~ /-$/);
                    $etag .= ( sprintf "%x", $stats[7] );
                }
            }
            else {
                my $sha = Digest::SHA->new;
                $sha->add( @{ $res->[2] } );
                $etag = $sha->hexdigest;
            }
            Plack::Util::header_set( $headers, 'ETag', $etag );
            $self->_set_cache_control($headers);
            return;
        }
    );
}

sub _set_cache_control {
    my ( $self, $headers ) = @_;
    return unless $self->cache_control;

    if ( ref $self->cache_control && ref $self->cache_control eq 'ARRAY' ) {
        Plack::Util::header_set( $headers, 'Cache-Control',
            join( ', ', @{ $self->cache_control } ) );
    }
    else {
        Plack::Util::header_set( $headers, 'Cache-Control', 'must-revalidate' );
    }
}

1;
__END__

=head1 NAME

Plack::Middleware::ETag - Adds automatically an ETag header.

=head1 SYNOPSIS

  use Plack::Builder;

  my $app = builder {
    enable "Plack::Middleware::ETag", file_etag => [qw/inode mtime size/];
    sub {['200', ['Content-Type' => 'text/html'}, ['hello world']]};
  };

=head1 DESCRIPTION

Plack::Middleware::ETag adds automatically an ETag header. You may want to use it with C<Plack::Middleware::ConditionalGET>.

  my $app = builder {
    enable "Plack::Middleware::ConditionalGET";
    enable "Plack::Middleware::ETag", file_etag => "inode";
    sub {['200', ['Content-Type' => 'text/html'}, ['hello world']]};
  };

=head2 CONFIGURATION

=over 4

=item file_etag

If the content is a file handle, the ETag will be set using the inode, modified time and the file size. You can select which attributes of the file will be used to set the ETag:

    enable "Plack::Middleware::ETag", file_etag => [qw/size/];

=item cache_control

It's possible to add 'Cache-Control' header.

    enable "Plack::Middleware::ETag", cache_control => 1;

Will add "Cache-Control: must-revalidate" to the headers.

    enable "Plack::Middleware::ETag", cache_control => [ 'must-revalidate', 'max-age=3600' ];

Will add "Cache-Control: must-revalidate, max-age=3600" to the headers.

=back

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
