#!/usr/bin/perl -w

use strict;
use utf8;
use MediaWiki::API;
use Irssi;
use WikiCommon;

our $VERSION = "20091123";
our %IRSSI   = (
	authors     => 'pl:User:Beau',
	contact     => 'beau@adres.pl',
	name        => 'wiki-admins',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~masti',
);

my %wiki_channels;

$wiki_channels{'#mst'} = {
        'url' => 'https://pl.wikipedia.org/w/api.php',    #
};

$wiki_channels{'#wikipedia-pl'} = {
	'url' => 'https://pl.wikipedia.org/w/api.php',    #
};

$wiki_channels{'#wiktionary-pl'} = {
	'url' => 'https://pl.wiktionary.org/w/api.php',    #
};

$wiki_channels{'#wikisource-pl'} = {
	'url' => 'https://pl.wikisource.org/w/api.php',    #
};

$wiki_channels{'#wikibooks-pl'} = {
	'url' => 'https://pl.wikibooks.org/w/api.php',    #
};

foreach my $settings ( values %wiki_channels ) {
	$settings->{admins}         = {};
	$settings->{admins_fetched} = 0;
}

# -------------------------------------------------------------------

sub rcadmins($) {
	my $data = shift;

	my $api = MediaWiki::API->new( 'url' => $data->{url}, );

	if ( time() - $data->{admins_fetched} > 3600 ) {
		my $response = $api->query(
			'action'  => 'query',
			'list'    => 'allusers',
			'augroup' => 'sysop',
			'aulimit' => 'max',
		);
		my @list = values %{ $response->{query}->{allusers} };
		$data->{admins} = { map { $_->{name} => 1 } @list };
	}

	my $response = $api->query(
		'action'  => 'query',
		'list'    => 'recentchanges',
		'rcprop'  => 'user',
		'rclimit' => 100,
		'rcshow'  => '!bot',
	);

	my %nicks;
	foreach my $item ( values %{ $response->{query}->{recentchanges} } ) {
		my $nick = $item->{user};
		next unless exists $data->{admins}->{$nick};
		$nicks{$nick}++;
	}
	return sort keys %nicks;
}

sub message {
	my ( $server, $args, $sender, $address ) = @_;
	my ( $target, $msg ) = $args =~ /^(\S+) :(.+)$/;

	my $settings = $wiki_channels{$target};
	return
	  unless defined $settings;

	my $channel = $server->channel_find($target);
	return unless $channel;

	return unless isActive($server, $channel);

	if ( $msg =~ /^!help$/ ) {
		$server->command("notice $sender !admini - wyświetla listę aktywnych administratorów");
		return;
	}

	return
	  unless $msg =~ /^!admin[yi]$/i;

	eval {
		my $list = join( ', ', rcadmins($settings) );
		if ( $list ne '' ) {
			$server->command("msg $target $sender: admini na OZ (100 ostatnich edycji): $list");
		}
		else {
			$server->command("msg $target $sender: Uuups! Chyba nie ma adminów na OZ!");
		}
	};
	if ($@) {
		$server->command("msg $target $sender: wystąpił błąd: $@");
	}
}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8
