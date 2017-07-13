#!/usr/bin/perl -w

use strict;
use utf8;
use MediaWiki::API;
use MediaWiki::Utils qw(from_wiki_timestamp);
use Irssi;
use WikiCommon;

our $VERSION = "20111111";
our %IRSSI   = (
	authors     => 'pl:User:Beau',
	contact     => 'beau@adres.pl',
	name        => 'wiki-seen',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~beau',
);

my %wiki_channels;


$wiki_channels{'#mst'} = {
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

$wiki_channels{'#cvn-wp-pl'} = {
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

$wiki_channels{'#wikimedia-pl'} = {
        'project' => 'wikipedia',
        'lang'    => 'pl',
};


sub interval {
	my $time   = shift;
	my $result = '';
	use integer;
	if ( $time > 31556926 ) {
		$result .= $time / 31556926 . "y ";
		$time %= 31556926;
	}
	if ( $time > 604800 ) {
		$result .= $time / 604800 . "w ";
		$time %= 604800;
	}
	if ( $time > 86400 ) {
		$result .= $time / 86400 . "d ";
		$time %= 86400;
	}
	if ( $time > 3600 ) {
		$result .= $time / 3600 . "h ";
		$time %= 3600;
	}
	if ( $time > 60 ) {
		$result .= $time / 60 . "m ";
		$time %= 60;
	}
	if ( $time > 0 ) {
		$result .= $time . "s ";
	}
	$result =~ s/ $//;
	$result =~ s/^(\S+\s\S+\s\S+)\s.+$/$1/;
	return $result;
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
		$server->command("notice $sender !wseen <nick> - podaje czas ostatniej edycji (przykład !wseen masti)");
		$server->command("notice $sender !wseen-<lang> <nick> - podaje czas ostatniej edycji (przykład !wseen-en masti)");
	}

	return
	  unless $msg =~ /^\s*!?\s*wseen(|-\S+)\s+(.+)$/;

	my $prefix = $1;
	my $login  = $2;
	$prefix =~ s/^-//;
	$prefix = $settings->{lang} if $prefix eq '';

	my $api = MediaWiki::API->new( 'url' => "https://$prefix.$settings->{project}.org/w/api.php", );
	eval {

		my $data = $api->query(
			'action'  => 'query',
			'list'    => 'users|usercontribs|logevents',
			'ususers' => $login,
			'usprop'  => 'gender',
			'ucuser'  => $login,
			'uclimit' => 1,
			'leuser'  => $login,
			'lelimit' => 1,
			'maxlag'  => 20,
		);

		my $le = $data->{query}->{logevents}->{0}->{timestamp};
		$le ||= '0';
		my $uc = $data->{query}->{usercontribs}->{0}->{timestamp};
		$uc ||= '0';

		$login = $data->{query}->{users}->{0}->{name};
		my $gender = $data->{query}->{users}->{0}->{gender};
		my $verb   = 'edytował(a)';
		$verb = 'edytował'  if $gender eq 'male';
		$verb = 'edytowała' if $gender eq 'female';

		if ( $le eq '0' and $uc eq '0' ) {
			$server->command( "msg $target $sender: $login jeszcze nie $verb. https://$prefix.$settings->{project}.org/wiki/Special:Contributions/" . escape($login) );
		}
		else {
			my $time = from_wiki_timestamp( ( $le gt $uc ) ? $le : $uc );
			my $currentTime = $api->expandtemplates( 'text' => '{{#time:U}}' );

			$server->command( "msg $target $sender: $login ostatnio $verb " . interval( $currentTime - $time ) . " temu. https://$prefix.$settings->{project}.org/wiki/Special:Contributions/" . escape($login) );
		}
	};
	if ($@) {
		if ( defined $api->error and $api->error->{code} eq 'leparam_user' ) {
			$server->command("msg $target $sender: $login nie jest zarejestrowaną nazwą użytkownika");
		}
		else {
			$server->command("msg $target $sender: wystąpił błąd: $@");
		}
	}

}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8
