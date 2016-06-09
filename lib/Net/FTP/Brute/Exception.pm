package Net::FTP::Brute::Exception;

use Modern::Perl '2014';
use warnings FATAL => 'all';
use Carp;

use Exception::Class (
    'Net::FTP::Brute::Exception' => {
        description => 'Net::FTP::Brute exceptions base class',
    },
);

sub newFromDie {
    my ($class, $die) = @_;
    return Net::FTP::Brute->new(error => "$die");
}

return 1;
