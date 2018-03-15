package Mercury::Controller::PubSub::Cascade;
our $VERSION = '0.017';
# ABSTRACT: Pub/sub controller with a topic heirarchy and cascading

=head1 SYNOPSIS

    # myapp.pl
    use Mojolicious::Lite;
    plugin 'Mercury';
    websocket( '/pub/*topic' )
      ->to( controller => 'PubSub::Cascade', action => 'pub' );
    websocket( '/sub/*topic' )
      ->to( controller => 'PubSub::Cascade', action => 'sub' );

=head1 DESCRIPTION

This controller enables a L<pubE<sol>sub pattern|Mercury::Pattern::PubSub> on
a pair of endpoints (L<publish|/publish> and L<subscribe|/subscribe>.

In this variant, topics are organized into a heirarchy. Subscribers can
subscribe to higher branch of the tree to recieve messages from all the
publishers on lower branches of the tree. So, a subscriber to C</foo>
will receive messages sent to C</foo>, C</foo/bar>, and C</foo/bar/baz>.

For more information on the pub/sub pattern, see L<Mercury::Pattern::PubSub>.

=head1 SEE ALSO

=over

=item L<Mercury::Pattern::PubSub>

=item L<Mercury::Controller::PubSub>

=item L<Mercury>

=back

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mercury::Pattern::PubSub;

=method publish

    $app->routes->websocket( '/pub/*topic' )
      ->to( controller => 'PubSub::Cascade', action => 'publish' );

Controller action to connect a websocket as a publisher. A publish
client sends messages through the socket. The message will be sent to
all of the connected subscribers for the topic and all parent topics.

This endpoint requires a C<topic> in the stash.

=cut

sub publish {
    my ( $c ) = @_;
    my $topic = $c->stash( 'topic' );
    my $pattern = $c->_pattern( $topic );
    $pattern->add_publisher( $c->tx );

    # Send messages to parent topics
    $c->tx->on( message => sub {
        my ( $tx, $msg ) = @_;
        $c->_send_message( $topic, $msg );
    } );

    $c->rendered( 101 );
}

=method subscribe

    $app->routes->websocket( '/sub/*topic' )
      ->to( controller => 'PubSub::Cascade', action => 'subscribe' );

Controller action to connect a websocket as a subscriber. A subscriber
will recieve every message sent by publishers to the current topic and
any child topics.

This endpoint requires a C<topic> in the stash.

=cut

sub subscribe {
    my ( $c ) = @_;
    my $pattern = $c->_pattern( $c->stash( 'topic' ) );
    $pattern->add_subscriber( $c->tx );
    $c->rendered( 101 );
}

=method post

Post a new message to the given topic without subscribing or
establishing a WebSocket connection. This allows new messages to be
pushed by any HTTP client.

=cut

sub post {
    my ( $c ) = @_;
    my $topic = $c->stash( 'topic' );
    my $pattern = $c->_pattern( $topic );
    $pattern->send_message( $c->req->body );
    $c->_send_message( $topic, $c->req->body );
    $c->render(
        status => 200,
        text => '',
    );
}

#=method _pattern
#
#   my $pattern = $c->_pattern( $topic );
#
# Get or create the L<Mercury::Pattern::PubSub> object for the given
# topic.
#
#=cut

sub _pattern {
    my ( $c, $topic ) = @_;
    my $pattern = $c->mercury->pattern( 'PubSub::Cascade' => $topic );
    if ( !$pattern ) {
        $pattern = Mercury::Pattern::PubSub->new;
        $c->mercury->pattern( 'PubSub::Cascade' => $topic => $pattern );
    }
    return $pattern;
}

#=method _send_message
#
#   $c->_send_message( $topic, $msg );
#
# Send the given message out on all the appropriate topics. This handles
# the "Cascade" part.
#=cut

sub _send_message {
    my ( $c, $topic, $msg ) = @_;
    my @parts = split m{/}, $topic;
    my @patterns =
        # Only pattern objects that have been created
        grep { defined }
        # Change topics into pattern objects
        map { $c->mercury->pattern( 'PubSub::Cascade' => $_ ) }
        # Build parent topics
        map { join '/', @parts[0..$_] }
        0..$#parts-1;
    $_->send_message( $msg ) for @patterns;
}

1;
