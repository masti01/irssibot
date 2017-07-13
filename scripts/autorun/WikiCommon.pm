package WikiCommon;
require Exporter;

use strict;

use Env;
use Data::Dumper;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(escape isActive);
our @EXPORT_OK = qw();
our $VERSION   = 20111111;

sub escape($) {
	my ($text) = @_;
	utf8::encode($text) if utf8::is_utf8($text);
	$text =~ tr/ /_/;
	$text =~ s/([^a-zA-Z0-9_\/\-.:])/uc sprintf("%%%02x",ord($1))/eg;
	return $text;
}

our $isMaster = undef;

sub isActive($$) {
	my $server  = shift;
	my $channel = shift;

	unless ( defined $isMaster ) {
		$isMaster = -e "$ENV{HOME}/.irssi/master";
	}

	return 1 if $isMaster;

	foreach my $user ( $channel->nicks ) {
		next if $user->{nick} eq $server->{nick};
		return 0 if index( $user->{nick}, 'BeauBot' ) > -1;
	}

	return 1;
}

eval {    #
	Log::Log4perl->init('log4perl.conf');
};

1;

# perltidy -et=8 -l=0 -i=8
