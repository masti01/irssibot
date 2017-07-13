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
	name        => 'wiki-test',
	description => 'Utility for wiksource channel',
	license     => 'GPL',
	url         => 'http://tools.wikimedia.pl/~masti',
);

my %wiki_channels;

#$wiki_channels{'#mst'} = {
#	'url'    => 'https://pl.wikipedia.org/w/api.php',
#	'prefix' => 'pl',
#};

#$wiki_channels{'#wikisource-pl'} = {
#	'url'    => 'https://pl.wikisource.org/w/api.php',
#	'prefix' => 'pl',
#};

$wiki_channels{'#pl.wikisource'} = {
	'url'    => 'https://pl.wikisource.org/w/api.php',
	'prefix' => 'pl',
};


foreach my $settings ( values %wiki_channels ) {
        print 'setting settings';
	$settings->{prefixes}  = undef;
	$settings->{urls}      = undef;
	$settings->{timestamp} = 0;
}

sub escapeAnchor {
	my $text = shift;
        print "escape anchor: $text";
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

        # test printouts
        open(my $handle, '>>', "$ENV{HOME}/.irssi/test.log") or die "Fatal: $!";
        #print $handle "srv:$server;args:$args;snd:$sender;addr:$address*\n";
        print $handle "msg:$msg\n";
        #print "msg:$msg";
        #print "page:$spage;flg:$sflags;usr:$suser,sec:$ssection,sum:$ssummary";

        print "page:$spage";

        my $sns;
        my $ssubpage;
        my $stable;

        
        #my ( $sns, $ssubpage, $stable) = $spage =~ m{(.*?):(.*?)\/(.*)};
        if ( $spage =~ /.*:.*/) {
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

        print "sns:$sns, subpage:$ssubpage, tbl:$stable";


        #if ( $ssubpage !~ /Skryptorium/ ) {
        #    print "Not a Skryptorium edit\n";
        #    close $handle;
        #    return
        #} else {
        #    print $handle "page:$spage;sur:$suser,sec:$ssection,sum:$ssummary";
        #    print "page:$spage;usr:$suser,sec:$ssection,sum:$ssummary";
        #}
        close $handle;
     
        #print 'Checking for srv/channel';   
     
        my $outserver = Irssi::server_find_chatnet('freenode');

	my $outchannel = $outserver->channel_find('#wikisource-pl');
	return unless $outchannel;

        # print test info
        #print "srv:$server;osrv:$outserver,chan:$outchannel";

        # print message to #mst channel
        my $mychan = '#mst';
 
        $outserver->command("MSG $mychan $msg");
        
        # workaround for encoding problems
        my $m1 = "wprowadził(a) zmiany";
        $m1 = $m1 . " w wątku " unless $ssection !~ /.+/ ;
        utf8::encode($m1);
        $m1 = $m1 . $ssection unless $ssection !~ /.+/ ;

        # combine response based on sections
        my $msg1 = "MSG $mychan $suser $m1 na stronie [[$sns";
        $msg1 = $msg1 . ":$ssubpage" unless $ssubpage !~ /.+/ ;
        $msg1 = $msg1 . "/$stable" unless $stable !~ /.+/;
        $msg1 = $msg1 . "]]";
        if ($ssummary =~ /.+/) {$msg1 = $msg1 . " z opisem zmian:$ssummary"}
        else {$msg1 = $msg1 . " bez opisu zmian"};

        print "msg1:$msg1";

        #if ( $ssummary !~ /^.+/) {
            #$msg1  = encode_utf8("MSG $mychan $suser wprowadził zmiany w wątku $ssection na stronie [[$spage/$ssubpage/$stable]] bez opisu zmian");
            #$outserver->command("MSG $mychan $suser $m1 $ssection na stronie [[$spage/$ssubpage/$stable]] bez opisu zmian");
        #} else {
            #$msg1  = encode_utf8("MSG $mychan $suser wprowadził zmiany w wątku $ssection na stronie [[$spage/$ssubpage/$stable]] z opisem zmian:$ssummary");
            #$outserver->command("MSG $mychan $suser $m1 $ssection na stronie [[$spage/$ssubpage/$stable]] z opisem zmian:$ssummary");
        #}
       
        $outserver->command("$msg1");

        #utf8::decode($msg1);
        #utf8::encode($msg1);
        #print "msg1:$msg1";
        #$outserver->command("MSG $mychan zażółć gęślą jaźń");
        #$outserver->command($msg1);
        #$outserver->command("MSG $mychan page:[[$spage]]; flg:$sflags; usr:[[User:$suser]]; sec:$ssection; sum:$ssummary");
        #$outserver->command("MSG $mychan ns:$sns; sub:$ssubpage; tab:$stable");
        $outserver->command("MSG $mychan $sdiff");

        return;

	#return unless isActive( $server, $channel );

	#return if $channel->nick_find('stvbot');
	#return if $channel->nick_find('omenamehu');
	#return if $msg =~ /#$/;

	#$msg =~ s/\{\{(.+?)\}\}/[[Template:$1]]/g;
	#my @links = $msg =~ /\[\[(.+?)\]\]/g;


}

Irssi::signal_add_last( "event privmsg", "message" );

# perltidy -et=8 -l=0 -i=8

__END__

my $text   = '1234567890[]{}\\|;:\'",<>.?/`~!@#$% ^&*()-_+= Zażółć gęślą jaźń';
my $result = '1234567890.5B.5D.7B.7D.5C.7C.3B:.27.22.2C.3C.3E..3F.2F.60.7E.21.40.23.24.25_.5E.26.2A.28.29-_.2B.3D_Za.C5.BC.C3.B3.C5.82.C4.87_g.C4.99.C5.9Bl.C4.85_ja.C5.BA.C5.84';
