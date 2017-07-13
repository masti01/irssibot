#!/usr/bin/perl -w

use strict;
use utf8;
use MediaWiki::API;
use Irssi;
use WikiCommon;

our $VERSION = "20111111";
our %IRSSI   = (
	authors     => 'pl:User:Beau',
	contact     => 'beau@adres.pl',
	name        => 'wiki-link',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~beau',
);

my %wiki_channels;

$wiki_channels{'#wikipedia-pl'} = {
	'url'    => 'https://pl.wikipedia.org/w/api.php',
	'prefix' => 'pl',
};

$wiki_channels{'#wiktionary-pl'} = {
	'url'    => 'https://pl.wiktionary.org/w/api.php',
	'prefix' => 'pl',
};

$wiki_channels{'#wikisource-pl'} = {
	'url'    => 'https://pl.wikisource.org/w/api.php',
	'prefix' => 'pl',
};

$wiki_channels{'#wikibooks-pl'} = {
	'url'    => 'https://pl.wikibooks.org/w/api.php',
	'prefix' => 'pl',
};

$wiki_channels{'#wikipedia-szl'} = {
        'url'    => 'https://szl.wikipedia.org/w/api.php',
        'prefix' => 'szl',
};

$wiki_channels{'#wikimedia-pl'} = {
        'url'    => 'https://pl.wikimedia.org/w/api.php',
        'prefix' => 'pl',
};

foreach my $settings ( values %wiki_channels ) {
	$settings->{prefixes}  = undef;
	$settings->{urls}      = undef;
	$settings->{timestamp} = 0;
}

sub escapeAnchor {
	my $text = shift;
	utf8::encode($text)
	  if utf8::is_utf8($text);

	$text =~ tr/ /_/;
	$text =~ s/([^a-zA-Z0-9_:\.-])/uc sprintf(".%02x",ord($1))/eg;
	return $text;
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

	return if $channel->nick_find('stvbot');
	return if $channel->nick_find('omenamehu');
	return if $msg =~ /#$/;

	$msg =~ s/\{\{(.+?)\}\}/[[Template:$1]]/g;
	my @links = $msg =~ /\[\[(.+?)\]\]/g;

	return unless @links;

	if ( !defined $settings->{prefixes} or time() - $settings->{timestamp} > 24 * 3600 ) {
		eval {
			my $api = MediaWiki::API->new( 'url' => $settings->{url}, );
			my @map = $api->getInterwikiMap;

			die "Interwikimap is empty\n" unless @map;

			my @prefixes = map { quotemeta( $_->{prefix} ) } @map;
			local $" = '|';
			$settings->{prefixes}  = qr/(?:@prefixes)/i;
			$settings->{urls}      = { map { lc( $_->{prefix} ) => $_->{url} } @map };
			$settings->{timestamp} = time();

		};
		if ($@) {
			warn $@;
		}
	}

	if ( !defined $settings->{prefixes} ) {
		warn "Unable to fetch interwikimap\n";
		return;
	}

	my @urls;
	my %urls;
	foreach my $link (@links) {
		$link =~ s/\|.*$//;
		my $anchor;
		if ( $link =~ s/\#(.*)$// ) {
			$anchor = $1;
		}

		$link =~ s/^://;

		next if $link eq '';

		( my $prefix, $link ) = $link =~ m/^(?:($settings->{prefixes}):)?(.*?)$/;
		next if $link eq '';

		$prefix = $settings->{prefix} unless defined $prefix;

		my $url = $settings->{urls}->{ lc $prefix };
		unless ( defined $url ) {
			warn "Unable to find url for prefix $prefix\n";
			next;
		}
		$link = escape($link);
		$url =~ s/\$1/$link/;
		$url =~ s{^http://([^.]+\.wik(?:ipedia|tionary|iquote|ibooks|inews|imedia|iversity|isource)\.org)}{https://$1};

		if ( defined $anchor ) {
			$url .= '#' . escapeAnchor($anchor);
		}

		next if exists $urls{$url};
		$urls{$url}++;
		push @urls, $url;
	}

	if (@urls) {
		$server->command( "msg $target " . join( ' ', @urls ) );
	}
}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8

__END__

my $text   = '1234567890[]{}\\|;:\'",<>.?/`~!@#$% ^&*()-_+= Zażółć gęślą jaźń';
my $result = '1234567890.5B.5D.7B.7D.5C.7C.3B:.27.22.2C.3C.3E..3F.2F.60.7E.21.40.23.24.25_.5E.26.2A.28.29-_.2B.3D_Za.C5.BC.C3.B3.C5.82.C4.87_g.C4.99.C5.9Bl.C4.85_ja.C5.BA.C5.84';
