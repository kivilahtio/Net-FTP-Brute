#!perl -T
use Modern::Perl '2014';
use warnings FATAL => 'all';
use Test::More;

use Net::FTP::Brute;

my $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
my $ftp = $brute->getWorkingConnection();

is(ref($ftp), 'Net::FTP', 'Got a Net::FTP-object');

done_testing();
