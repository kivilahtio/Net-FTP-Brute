package Net::FTP::Brute::Exception::Connection;

use Modern::Perl '2014';
use warnings FATAL => 'all';
use Carp;

use Exception::Class (
    'Net::FTP::Brute::Exception::Connection' => {
        isa => 'Net::FTP::Brute::Exception',
        description => "Making a ftp-connection failed.",
        fields => ['Host', 'Port'],
    },
);

return 1;
