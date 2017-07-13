#!/usr/bin/perl -w

use strict;
use vars qw($VERSION %IRSSI);
use utf8;
use Data::Dumper;
use Irssi;

$VERSION = "1.1";
%IRSSI = (
    authors     => 'Szymon Świerkosz',
    contact     => 'szymek@adres.pl',
    name        => 'wiki-stalk',
    description => 'Utility for wikipedians\' channel',
    license     => 'GFDL',
    url         => '',
);

my %wiki_channels = (
	'#wikipedia-pl' => {
		'stalkwords' => {
			'!admin' => 'Uwaga admini, $1 czegoś chce! $2',
			'!commons' => 'Uwaga admini commons, $1 czegoś chce! $2',,
		},
		'min_interval' => 300,
	},
	'#wikipedia-bzz' => {
		'stalkwords' => {
			'!admin' => 'Uwaga admini, $1 czegoś chce! $2',
			'!commons' => 'Uwaga admini commons, $1 czegoś chce! $2',,
	},
		},
		'min_interval' => 300,
	'#mst' => {
		'stalkwords' => {
			'!admin' => 'Uwaga admini, $1 czegoś chce! $2',
			'!commons' => 'Uwaga admini commons, $1 czegoś chce! $2',,
		},
		'min_interval' => 300,
	},
);

sub load {
	unless ( open(DATA, "<wiki-stalk.txt") ) {
		print "Nie można otworzyć pliku do odczytu: $!";
		return;
	}

	while (<DATA>) {
		print "Invalid format" and next unless /^(\S+):(\S+):(.+)\n$/;
		next unless exists $wiki_channels{$1};
		next unless exists $wiki_channels{$1}->{stalkwords}->{$2};
		$wiki_channels{$1}->{list}->{$2} = [ split ' ', $3 ];
	}

	close(DATA);
}

sub save {
	unless ( open(DATA, ">wiki-stalk.txt") ) {
		print "Nie można otworzyć pliku do zapisu: $!";
		return;
	}

	foreach my $channel (keys %wiki_channels) {
		my $settings = $wiki_channels{$channel};
		next unless defined $settings->{list};
		foreach my $word (keys %{ $settings->{list} }) {
			my @list = @{ $settings->{list}->{$word} };
			local $" = ' ';
			print DATA "$channel:$word:@list\n";
		}
	}

	close(DATA);

}

sub message {
	my ($server, $args, $sender, $address) = @_;
	my ($target, $msg) = $args =~ /^(\S+) :(.+)$/;

	my $settings = $wiki_channels{$target};
	return
	  unless defined $settings;


	my $re = join("|", keys %{ $settings->{stalkwords} });

	if ($msg =~ /^(?:$re)$/i) {
		my $word = lc $msg;
		if (defined $settings->{last_use}->{$word} and time() - $settings->{last_use}->{$word} < $settings->{min_interval}) {
			$server->command("notice $sender Ktoś przed chwilą już użył tego polecenia.");
			return;
		}
		$settings->{last_use}->{$word} = time();
		my $response = $settings->{stalkwords}->{$word};
		my $list;
		if (defined $settings->{list}->{$word} and scalar @{ $settings->{list}->{$word} }) {
			$list = join(", ", @{ $settings->{list}->{$word} });
		}
		else {
			$list = 'nikt sie nie chciał przyznać do swoich uprawnień';
		}
		$response =~ s/\$1/$sender/;
		$response =~ s/\$2/$list/;

		$server->command("msg $target $response");
	}
	elsif ($msg =~ /^!(?:dodaj|add) (\S+)(?: ([A-Za-z0-9_\-\\\^]+))?$/i) {
		my $word = lc $1;
		my $nick = defined $2 ? $2 : $sender;

		unless ($address =~ m{\@wiki[pm]edia/}i) {
			$server->command("notice $sender Nie masz uprawnień do wykonania tego polecenia, poproś kogoś z cloakiem.");
		}

		unless (defined $settings->{stalkwords}->{$word}) {
			$server->command("msg $target $sender: nieprawidłowy argument, dostępne możliwości to: " . join(" ", keys %{ $settings->{stalkwords} }));
		}

		my $list = defined $settings->{list}->{$word} ? $settings->{list}->{$word} : [];
		foreach my $item (@{ $list }) {
			if (lc $item eq lc $nick) {
				$server->command("msg $target $sender: ten wpis znajduje się już na liście");
				return;
			}
		}
		push @{ $list }, $nick;
		$settings->{list}->{$word} = $list;
		$server->command("msg $target $sender: okay");
		save;
	}
	elsif ($msg =~ /^!(?:del|remove|usu[ńn]) (\S+)(?: (\S+))?$/i) {
		my $word = lc $1;
		my $nick = defined $2 ? $2 : $sender;

		unless ($address =~ m{\@wiki[pm]edia/}i) {
			$server->command("notice $sender Nie masz uprawnień do wykonania tego polecenia, poproś kogoś z cloakiem.");
		}

		unless (defined $settings->{stalkwords}->{$word}) {
			$server->command("msg $target $sender: nieprawidłowy argument, dostępne możliwości to: " . join(" ", keys %{ $settings->{stalkwords} }));
		}

		my $newlist = [];
		my $list = defined $settings->{list}->{$word} ? $settings->{list}->{$word} : [];
		my $found = 0;

		foreach my $item (@{ $list }) {
			if (lc $item eq lc $nick) {
				$found++;
			}
			else {
				push @{ $newlist }, $item;
			}
		}
		$settings->{list}->{$word} = $newlist;
		if ($found) {
			$server->command("msg $target $sender: okay");
			save;
		}
		else {
			$server->command("msg $target $sender: nie ma czego usuwać");
		}
	}
}

Irssi::signal_add_last("event privmsg", "message");

load;
