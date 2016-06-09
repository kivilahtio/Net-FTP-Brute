package Net::FTP::Brute::Exception::Login;

use Modern::Perl '2014';
use warnings FATAL => 'all';
use Carp;

use Exception::Class (
    'Net::FTP::Brute::Exception::Login' => {
        isa => 'Net::FTP::Brute::Exception',
        description => "Logging to the ftp-server failed.",
        fields => ['Host', 'Port', 'Login'], #username of the authenticatee.
    },
);

return 1;
