#!/usr/bin/perl -w

use strict;
use utf8;
use MediaWiki::API;
use Wiki::Votes;
use Irssi;
use WikiCommon;

our $VERSION = "20091123";
our %IRSSI   = (
	authors     => 'pl:User:Beau',
	contact     => 'beau@adres.pl',
	name        => 'wiki-pu',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~beau',
);

my %wiki_channels;

$wiki_channels{'#wikipedia-pl'} = {
	'last' => 0,
	'url'  => 'https://pl.wikipedia.org/w/api.php',
};

sub removePrefix($$) {
	my ( $title, $prefix ) = @_;

	$prefix .= '/';
	my $extractedPrefix = substr( $title, 0, length($prefix), '' );
	die unless $extractedPrefix eq $prefix;
	return $title;
}

sub message {
	my ( $server, $args, $sender, $address ) = @_;
	my ( $target, $msg ) = $args =~ /^(\S+) :(.+)$/;

	my $settings = $wiki_channels{$target};
	return
	  unless defined $settings;

	my $channel = $server->channel_find($target);
	return unless $channel;

	return unless isActive( $server, $channel );

	if ( $msg =~ /^!help$/ ) {
		$server->command("notice $sender !pu - pokazuje aktualne głosowania nad przyznawaniem uprawnień");
		return;
	}

	return
	  unless $msg =~ /^!pu$/i;

	return if time() - $settings->{'last'} < 300;
	$settings->{'last'} = time();

	eval {
		my $api = MediaWiki::API->new( 'url' => $settings->{url}, );

		my $page_prefix = 'Wikipedia:Przyznawanie uprawnień';
		my $re          = qr/====\s*Za\s*:?\s*====(.*?)====\s*Przeciw\s*:?\s*====(.*?)====\s*Wstrzymuję\s*się\s*:?\s*====(.*?)===/si;

		my @pages = get_subpages( $api, $page_prefix, $page_prefix, 'Wstęp' );

		if ( scalar @pages > 5 ) {
			$server->command("msg $target $sender: za dużo głosowań, rzuć okiem na stronę: 
http://tools.wikimedia.pl/~masti/votes.html");
		}
		elsif ( scalar @pages ) {
			$server->command("msg $target Aktualne wyniki głosowań - 
http://tools.wikimedia.pl/~masti/votes.html");
			foreach my $page ( get_results( $api, $re, @pages ) ) {
				my $subpage = removePrefix( $page->{title}, $page_prefix );

				my ( $za, $przeciw, $wstrz ) = map { scalar( @{$_} ) } @{ $page->{values} };
				my $message = "- $subpage, za: $za, przeciw: $przeciw, wstrzymało się: $wstrz";
				my $all     = $za + $przeciw;
				$message .= sprintf( ', procent: %.1f', $za / $all * 100 ) if $all;

				$server->command("msg $target $message");
			}
		}
		else {
			$server->command("msg $target $sender: Aktualne wyniki głosowań - 
http://tools.wikimedia.pl/~masti/votes.html - nie ma obecnie głosowań nad przyznawaniem uprawnień");
		}
	};
	if ($@) {
		$server->command("msg $target $sender: wystąpił błąd: $@");
	}
}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8
