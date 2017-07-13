#!/usr/bin/perl -w

use strict;
use Irssi;
use Env;
use IO::Socket::UNIX;

our $VERSION = "20090905";
our %IRSSI   = (
	authors     => 'pl:User:Beau',
	contact     => 'beau@adres.pl',
	name        => 'unixsocket',
	description => '',
	license     => 'GPL',
	url         => '',
);

my $path = "$ENV{HOME}/irssi.sock";
unlink($path);

my $server = IO::Socket::UNIX->new(
	Local  => $path,
	Type   => SOCK_DGRAM,
	Listen => 5
) or die $!;
chmod 0600, $path;

Irssi::input_add( fileno($server), INPUT_READ, \&handle_connection, undef );

sub handle_connection {
	my $data;
	$server->recv( $data, 512 );
	print "Received command: $data";

	my $server = Irssi::server_find_tag('freenode');
	unless ( $server and $server->{connected} ) {
		print "There is no connection named 'freenode'";
		return;
	}
	$server->command($data);
}

# perltidy -et=8 -l=0 -i=8
