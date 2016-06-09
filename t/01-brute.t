#!perl -T
use Modern::Perl '2014';
use warnings FATAL => 'all';
use Test::More;
use Test::MockModule;
use Scalar::Util qw(blessed);
use Try::Tiny;

use Net::FTP::Brute;
use Net::FTP;


use Net::FTP::Brute::Exception::Connection;


my $mockFTP = Test::MockModule->new('Net::FTP');
$mockFTP->mock('new', sub { return bless({}, 'Net::FTP') }); #Simply return a mock object



subtest "Connection without problems", \&noProblemSir;
sub noProblemSir {

    my $mockMod = Test::MockModule->new('Net::FTP::Brute');
    #throw no Exception, allow everything to pass smoothly
    $mockMod->mock('_testConnection', sub {
        return Net::FTP->new();
    });
    my ($brute, $ftp);


    $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
    $ftp = $brute->getWorkingConnection();
    ok(blessed($ftp) && $ftp->isa('Net::FTP'), "Connection succeeded");

    return 1;
}



subtest "Connection times out a few times but eventually network comes back on", \&networkDownButRecovers;
sub networkDownButRecovers {

    my $mockMod = Test::MockModule->new('Net::FTP::Brute');
    #throw Connection-Exception 5 times, then allow everything to pass smoothly
    my $i = 0;
    $mockMod->mock('_testConnection', sub {
        if ($i >= 5) {
            return Net::FTP->new();
        }
        $i++;
        Net::FTP::Brute::Exception::Connection->throw();
    });
    my ($brute, $ftp);


    $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
    $ftp = $brute->getWorkingConnection();
    ok(blessed($ftp) && $ftp->isa('Net::FTP'), "Connection succeeded");
    is($i, 5, "5 Net::FTP::Brute::Exception::Connection thrown");

    return 1;
}



subtest "Connection times out and never comes back on", \&networkDownForGood;
sub networkDownForGood {

    my $mockMod = Test::MockModule->new('Net::FTP::Brute');
    #throw Connection-Exception all the time
    $mockMod->mock('_testConnection', sub {
        Net::FTP::Brute::Exception::Connection->throw();
    });
    my ($brute, $ftp);


    try {
        $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
        $ftp = $brute->getWorkingConnection(5,5); #$forks, $retries, don't retry the default 100 times
    } catch {
        ok(blessed($_) && $_->isa('Net::FTP::Brute::Exception::Connection'), "Connection failed");
    };

    return 1;
}



subtest "DATA-connection cannot be established, so we need to retry 10 times", \&noDATA;
sub noDATA {

    my $mockMod = Test::MockModule->new('Net::FTP::Brute');
    #throw DATA-Exception 10 times, then allow everything to pass smoothly
    my $i = 0;
    $mockMod->mock('_testConnection', sub {
        if ($i >= 10) {
            return Net::FTP->new();
        }
        $i++;
        Net::FTP::Brute::Exception::DATA->throw();
    });
    my ($brute, $ftp);


    $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
    $ftp = $brute->getWorkingConnection();
    ok(blessed($ftp) && $ftp->isa('Net::FTP'), "Connection succeeded");
    is($i, 10, "10 Net::FTP::Brute::Exception::DATA thrown");

    return 1;
}



subtest "DATA-connection can never be established", \&DATADownForGood;
sub DATADownForGood {

    my $mockMod = Test::MockModule->new('Net::FTP::Brute');
    #throw Connection-Exception all the time
    $mockMod->mock('_testConnection', sub {
        Net::FTP::Brute::Exception::DATA->throw();
    });
    my ($brute, $ftp);


    try {
        $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
        $ftp = $brute->getWorkingConnection(5,5); #$forks, $retries, don't retry the default 100 times
    } catch {
        ok(blessed($_) && $_->isa('Net::FTP::Brute::Exception::DATA'), "DATA-connection failed");
    };

    return 1;
}



subtest "Login fails", \&badLogin;
sub badLogin {

    my $mockMod = Test::MockModule->new('Net::FTP::Brute');
    #throw Connection-Exception all the time
    $mockMod->mock('_testConnection', sub {
        Net::FTP::Brute::Exception::Login->throw();
    });
    my ($brute, $ftp);


    try {
        $brute = Net::FTP::Brute->new( Host => 'ftp.example.com', Port => 21, Passive => 1, Login => 'example', Password => '.com' );
        $ftp = $brute->getWorkingConnection(5,5); #$forks, $retries, don't retry the default 100 times
    } catch {
        ok(blessed($_) && $_->isa('Net::FTP::Brute::Exception::Login'), "Login failed");
    };

    return 1;
}



done_testing();
