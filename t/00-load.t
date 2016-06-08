#!perl -T
use Modern::Perl '2014';
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Net::FTP::Brute' ) || print "Bail out!\n";
}

diag( "Testing Net::FTP::Brute $Net::FTP::Brute::VERSION, Perl $], $^X" );
