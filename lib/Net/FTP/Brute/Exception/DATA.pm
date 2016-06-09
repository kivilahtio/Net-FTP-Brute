package Net::FTP::Brute::Exception::DATA;

use Modern::Perl '2014';
use warnings FATAL => 'all';
use Carp;

use Exception::Class (
    'Net::FTP::Brute::Exception::DATA' => {
        isa => 'Net::FTP::Brute::Exception',
        description => "Making a ftp DATA-connection failed.",
    },
);

return 1;
