#!/usr/bin/perl -w

use strict;
use utf8;
#no utf8;
#use Encode;
#use Encode::Guess;
#use open ':std', ':encoding(UTF-8)';
use MediaWiki::API;
use Irssi;
use WikiCommon;

our $VERSION = "20170620";
our %IRSSI   = (
	authors     => 'pl:User:masti',
	contact     => 'mastigm@gmail.com',
	name        => 'wikisource-szablonnowe',
	description => 'Utility for wiksource channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~masti',
);

my %wiki_channels;

$wiki_channels{'#pl.wikisource'} = {
	'url'    => 'https://pl.wikisource.org/w/api.php',
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

        #get edit sections from $msg
        my ( $spage, $sflags, $sdiff, $suser, $sbytes, $ssection, $ssummary ) = $msg =~ 
           /^.14\[\[.07(.+?).14\]\].4 (.*).10 .02(.+?). .5\*. .03(.+?). .5\*. \(([+-]?\d+?)\) .10(\/\*.*\*\/)?(.*)./;

        # logging
        open(my $handle, '>>', "$ENV{HOME}/.irssi/test.log") or die "Fatal: $!";
        print $handle "msg:$msg\n";

        #my ( $sns, $ssubpage, $stable) = $spage =~ m{(.*?):(.*?)\/(.*)};
        my $sns;
        my $ssubpage;
        my $stable;

        
        #my ( $sns, $ssubpage, $stable) = $spage =~ m{(.*?):(.*?)\/(.*)};
        if ( $spage =~ /.*Szablon:.*/) {
            ($sns , $ssubpage) = $spage =~ /(.*):(.*)/;
        } else {
            $sns = '';
            $ssubpage = $spage;
        }

        if ($ssubpage =~ m{(.*)\/(.*)}) {
            ($ssubpage, $stable) = $ssubpage =~ m{(.*)\/(.*)};
        } else {
            $stable = '';
        }
        print $handle "SKR sns:$sns, subpage:$ssubpage, tbl:$stable\n";

        if ( $ssubpage !~ /Nowe/ ) {
            close $handle;
            return
        } else {
            print $handle "SKR: page:$spage;sur:$suser,sec:$ssection,sum:$ssummary\n";
        }
        close $handle;
     
    
        my $outserver = Irssi::server_find_chatnet('freenode');

	my $outchannel = $outserver->channel_find('#wikisource-pl');
	return unless $outchannel;

        # print message to #wikisource-pl channel
        my $mychan = '#wikisource-pl';
        
        # workaround for encoding problems
        my $m1 = "wprowadził(a) zmiany";
        $m1 = $m1 . " w wątku " unless $ssection !~ /.+/ ;
        utf8::encode($m1);
        $m1 = $m1 . $ssection unless $ssection !~ /.+/ ;

        # combine response based on sections
        my $msg1 = "MSG $mychan $suser $m1 w szablonie {{";
        $msg1 = $msg1 . ":$ssubpage" unless $ssubpage !~ /.+/ ;
        $msg1 = $msg1 . "/$stable" unless $stable !~ /.+/;
        $msg1 = $msg1 . "}}";
        if ($ssummary =~ /.+/) {$msg1 = $msg1 . " z opisem zmian:$ssummary"}
        else {$msg1 = $msg1 . " bez opisu zmian"};

        print $handle "SKR msg1:$msg1\n";

        $outserver->command("$msg1");
        $outserver->command("MSG $mychan $sdiff");

        return;

}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8

__END__

my $text   = '1234567890[]{}\\|;:\'",<>.?/`~!@#$% ^&*()-_+= Zażółć gęślą jaźń';
my $result = '1234567890.5B.5D.7B.7D.5C.7C.3B:.27.22.2C.3C.3E..3F.2F.60.7E.21.40.23.24.25_.5E.26.2A.28.29-_.2B.3D_Za.C5.BC.C3.B3.C5.82.C4.87_g.C4.99.C5.9Bl.C4.85_ja.C5.BA.C5.84';
