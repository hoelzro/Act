package Act::Request;

use strict;
use warnings;
use parent 'Plack::Request';

use Encode qw(encode_utf8);
use Plack::Util::Accessor qw(response _body);

sub new {
    my ( $class ) = @_;

    my $self = Plack::Request::new(@_);

    $self->_body([]);
    $self->response($self->new_response(200, [], $self->_body));

    return $self;
}

sub no_cache {
    my ( $self, $dont_cache ) = @_;

    if($dont_cache) {
        $self->response->header('Cache-Control' => 'no-cache');
        $self->response->header('Pragma'        => 'no-cache');
    }
}

sub print {
    my $self = shift;

    push @{ $self->_body }, map { encode_utf8($_) } @_;
}

sub login {
    my ( $self, $user ) = @_;
    $self->env->{'act.auth.login'}->($self->response, $user);
}
sub logout {
    my ( $self ) = @_;
    $self->env->{'act.auth.logout'}->($self->response);
}
sub set_session {
    my ( $self, $sid, $remember_me ) = @_;
    $self->env->{'act.auth.set_session'}->($self->response, $sid, $remember_me);
}

sub send_http_header {
    my ( $self, $content_type ) = @_;

    return unless $content_type;

    $self->response->content_type($content_type);
}

sub upload {
    my ( $self ) = @_;
    my $uploads = $self->uploads;
    if (wantarray) {
        my @uploads = map { Act::Upload->new($_, $uploads->{$_}) } keys %$uploads;
        return @uploads;
    }
    my ($name) = keys %$uploads;
    return Act::Upload->new($name, $uploads->{$name});
}

{
    package Act::Upload;
    sub new {
        my $class = shift;
        my $name = shift;
        my $upload = shift;
        my $self = bless {
            name => $name,
            path => $upload->path,
            filename => $upload->filename,
            size => $upload->size,
            info => {},
            type => $upload->content_type,
        }, $class;
        return $self;
    }

    sub name { $_[0]->{name} }
    sub filename { $_[0]->{filename} }
    sub size { $_[0]->{size} }
    sub info { die "unimplemented" }
    sub type { $_[0]->{type} }
    sub tempname { $_[0]->{path} }
    sub link { die "unimplemented" }
    sub next { die "unimplemented" }
    sub fh {
        my $self = shift;
        my $fh = $self->{fh};
        return $fh if $fh;
        open $fh, '<', $self->{path};
        $self->{fh} = $fh;
        return $fh;
    }
}

1;

__END__

=head1 NAME

Act::Request - A subclass of Plack::Request that handles like Apache::Request

=head1 DESCRIPTION

=cut
