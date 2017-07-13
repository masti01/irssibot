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
	name        => 'wiki-replag',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~beau',
);

my %wiki_channels;

$wiki_channels{'#wikipedia-pl'} = {
	'url' => 'https://pl.wikipedia.org/w/api.php',    #
};

$wiki_channels{'#wikisource-pl'} = {
	'url' => 'https://pl.wikisource.org/w/api.php',    #
};

$wiki_channels{'#wiktionary-pl'} = {
	'url' => 'https://pl.wiktionary.org/w/api.php',    #
};

$wiki_channels{'#wikibooks-pl'} = {
	'url' => 'https://pl.wikibooks.org/w/api.php',    #
};

foreach my $settings ( values %wiki_channels ) {
	$settings->{last} = 0;
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
		$server->command("notice $sender !lag - wyświetla opóźnienia w replikacji");
		return;
	}

	return
	  unless $msg =~ /^!lag$/i;

	return if time() - $settings->{'last'} < 300;
	$settings->{'last'} = time();

	eval {
		my $api = MediaWiki::API->new( 'url' => $settings->{url}, );

		my $data = $api->query(
			'meta'        => 'siteinfo',
			'siprop'      => 'dbrepllag',
			'sishowalldb' => '',
		);
		my @list = values %{ $data->{query}->{dbrepllag} };
		@list = sort { $b->{lag} <=> $a->{lag} or $a->{host} cmp $b->{host} } @list;
		foreach my $item (@list) {
			my $lag  = $item->{lag};
			my $host = $item->{host};
			if ( $lag < 120 ) {
				$lag .= 's';
			}
			elsif ( $lag < 7200 ) {
				$lag = int( $lag / 60 ) . 'm';
			}
			else {
				$lag = int( $lag / 3600 ) . 'h';
			}
			$item = "$host: $lag";
		}

		local $" = ', ';
		$server->command("msg $target $sender: @list");
	};
	if ($@) {
		$server->command("msg $target $sender: wystąpił błąd: $@");
	}
}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8
