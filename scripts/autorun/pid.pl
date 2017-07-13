#!/usr/bin/perl -w

use strict;
use Irssi;
use Env;

open(my $handle, '>', "$ENV{HOME}/.irssi/irssi.pid") or die "Fatal: $!";
print $handle "$$\n";
close $handle;
