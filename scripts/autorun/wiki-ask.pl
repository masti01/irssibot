#!/usr/bin/perl -w

use strict;
use utf8;
use MediaWiki::API;
use HTML::Entities;
use Data::Dumper;
use Irssi;
use WikiCommon;

our $VERSION = "20120430";
our %IRSSI   = (
	authors     => 'pl:User:Beau',
	contact     => 'beau@adres.pl',
	name        => 'wiki-ask',
	description => 'Utility for wikipedians\' channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~beau',
);

my %wiki_channels;

$wiki_channels{'#mst'} = {
	'last'    => 0,
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

$wiki_channels{'#cvn-wp-pl'} = {
	'last'    => 0,
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

$wiki_channels{'#wiktionary-pl'} = {
	'last'    => 0,
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

$wiki_channels{'#wikisource-pl'} = {
	'last'    => 0,
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

$wiki_channels{'#wikibooks-pl'} = {
	'last'    => 0,
	'project' => 'wikipedia',
	'lang'    => 'pl',
};

# -------------------------------------------------------------------

sub findAnswer {
	my $api  = shift;
	my $what = shift;

	my $response;
	eval {    #
		$response = $api->query(
			'action'    => 'parse',
			'page'      => $what,
			'prop'      => 'text|revid|categories|displaytitle',
			'redirects' => '',
		);
	};
	if ( $@ and $api->{error}->{code} ne 'missingtitle' ) {
		die $@;
	}

	my @results;

	if ( defined $response and $response->{parse}->{revid} ) {
		my %categories;
		if ( $response->{parse}->{categories} ) {
			%categories = map { $_->{'*'} => 1 } values %{ $response->{parse}->{categories} };
		}

		#print Dumper \%categories, 'Strony_ujednoznaczniające';

		my $text = $response->{parse}->{text}->{'*'};

		#$text =~ s{<table[^>]+?class="infobox".+?</table>\s*}{}isg;
		#$text =~ s{<table[^>]+?class="[^>]+?(?:metadata|ambox).+?</table>\s*}{}isg;
		#$text =~ s{<table.+?</table>\s*}{}isg;

		while ( $text =~ s{<table[^<]*(?:<(?!table)[^<]*)*?</table>}{}isg ) { }
		$text =~ s{<p>.+?id="coordinates".+?</span></p>}{}isg;
		$text =~ s/<a name.+?<\/a>//g;

		$text =~ s/\s+/ /g;
		$text =~ s/<!--.*?-->//sg;

		#print "Refined:\n$text";

		if ( exists $categories{'Strony_ujednoznaczniające'} ) {
			@results = $text =~ /<li><a href="\/wiki\/[^:"]+" title="(.+?)"/sg;    #"
			@results = grep { !/^(?:Wikisłownik|Wikipedia|Wictionary)$/ } @results;
		}
		elsif ( $text =~ /\s*<p>(.+?)<\/p>/ ) {

			# definicja
			my $answer = $1;
			$answer =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
			$answer = decode_entities($answer);
			$answer =~ s/[:,;]$/.../;

			if ( length($answer) > 350 ) {
				$answer =~ /^(.{1,350}\s)/;
				$answer = "$1...";
			}

			my $name = $response->{parse}->{displaytitle};    # FIXME
			utf8::encode($name);

			my $link = $api->getGeneralSiteInfo('server') . $api->getGeneralSiteInfo('articlepath');
			$link =~ s{\$1}{escape($name)}e;
			$link =~ s{^(?:http:)?//}{https://};

			return $answer . " $link";
		}
	}

	unless (@results) {
		$response = $api->query(
			'list'        => 'search',
			'srnamespace' => '0|2|4',
			'srsearch'    => $what,
		);

		if ( $response->{query}->{searchinfo}->{suggestion} ) {
			push @results, $response->{query}->{searchinfo}->{suggestion};
		}

		#print Dumper $response;

		foreach my $result ( values %{ $response->{query}->{search} } ) {
			last if @results >= 5;
			push @results, $result->{title};
		}
	}

	local $" = ", ";
	if ( @results == 1 ) {
		return "Czy chodziło Ci o: @results?";
	}
	else {
		splice( @results, 10 ) if @results > 10;
		return "Wybierz jedno z: @results.";
	}

	return "nie wiem";
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

	return
	  unless index( lc($msg), lc( $server->{nick} ) ) > -1;

	my $q;
	my $lang = $settings->{lang};

	if ( $msg =~ /.+(?:co to|czym|kto to|kim) (?:jest |było? |bylo? |)(.*)/i ) {
		$q = $1;
		$q =~ s/^\s+//;
		$q =~ s/\s*[\.\?]*\s*$//;
	}
	elsif ( $msg =~ /.+(?:what|who|what's|who's) (?:are |is |was |were |)(.*)/i ) {
		$q = $1;
		$q =~ s/^\s+//;
		$q =~ s/\s*[\.\?]*\s*$//;
		$lang = 'en';
	}

	return
	  unless defined $q;

	my $api = MediaWiki::API->new( 'url' => "https://$lang.$settings->{project}.org/w/api.php", );

	eval { $server->command( "msg $target $sender: " . findAnswer( $api, $q ) ); };
	if ($@) {
		$server->command("msg $target $sender: wystąpił błąd: $@");
	}
}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8
