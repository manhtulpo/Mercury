package Mercury::Command::mercury;
our $VERSION = '0.016';
# ABSTRACT: Mercury command for Mojolicious

use Mojo::Base 'Mojolicious::Commands';

has description => 'Mercury message broker';
has hint        => <<EOF;

See 'APPLICATION mercury help COMMAND' for more information on a specific
command.
EOF

has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['Mercury::Command::mercury'] };

sub help { shift->run(@_) }

1;

=head1 SYNOPSIS

  Usage: APPLICATION mercury COMMAND [OPTIONS]

=head1 DESCRIPTION

L<Mercury::Command::mercury> lists available L<Mercury> commands.

=head1 SEE ALSO

=over 4

=item *

L<mercury>

=back

