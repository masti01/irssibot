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
	name        => 'wiki-counter',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~beau',
);

my %wiki_channels;

$wiki_channels{'#wikipedia-pl'} = {
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

$wiki_channels{'#wikisource-pl'} = {
	'project' => 'wikisource',
	'lang'    => 'pl',
};

$wiki_channels{'#wiktionary-pl'} = {
	'project' => 'wiktionary',
	'lang'    => 'pl',
};

$wiki_channels{'#wikibooks-pl'} = {
	'project' => 'wikibooks',
	'lang'    => 'pl',
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
		$server->command("notice $sender !count <nick> - licznik edycji (przykład !count masti)");
		$server->command("notice $sender !count-<lang> <nick> - licznik edycji (przykład !count-en masti)");
		return;
	}

	return
	  unless $msg =~ /^\s*!?\s*count(|-\S+)\s+(.+)$/;

	#return if time() - $settings->{'last'} < 300;
	$settings->{'last'} = time();

	my $prefix = $1;
	my $login  = $2;
	$prefix =~ s/^-//;
	$prefix = $settings->{lang} if $prefix eq '';

	eval {
		my $api = MediaWiki::API->new( 'url' => "https://$prefix.$settings->{project}.org/w/api.php", );

		my $data = $api->query(
			'action'  => 'query',
			'list'    => 'users',
			'ususers' => $login,
			'usprop'  => 'editcount|registration|emailable',
			'maxlag'  => 120,
		);

		#use Data::Dumper;
		#print Dumper($data);

		foreach my $user ( values %{ $data->{query}->{users} } ) {
			if ( exists $user->{invalid} ) {
				$server->command("msg $target $sender: $user->{name} nie jest prawidłową nazwą użytkownika");
			}
			elsif ( exists $user->{missing} ) {
				$server->command("msg $target $sender: $user->{name} nie jest zarejestrowaną nazwą użytkownika");
			}
			elsif ( exists $user->{editcount} ) {
				my $message = "$sender: $user->{name} ma edycji $user->{editcount}";
				if ( defined $user->{registration} ) {
					$message .= ", data rejestracji: $user->{registration}";
				}
				if ( defined $user->{emailable} ) {
					$message .= ', przyjmuje wiadomości e-mail';
				}
				$server->command("msg $target $message");
			}
			else {
				$server->command("msg $target $sender: nieznany błąd");
			}
		}
	};
	if ($@) {
		$server->command("msg $target $sender: wystąpił błąd: $@");
	}
}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8
