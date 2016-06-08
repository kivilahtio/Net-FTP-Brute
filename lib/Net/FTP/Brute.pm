package Net::FTP::Brute;

use Modern::Perl '2014';
use warnings FATAL => 'all';
use Carp;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{'Net_FTP_Brute_loglevel'} || $ERROR);

use Net::FTP;

=head1 NAME

Net::FTP::Brute - The great new Net::FTP::Brute!

=head1 VERSION

Version 0.01

=cut

our $VERSION = 0.01;


=head1 SYNOPSIS

Tries to find a way, for an ftp-connection, through an occasionally allowing corporate firewall.

    use Net::FTP::Brute;

    my $brute = Net::FTP::Brute->new();
    my $ftp = $brute->getWorkingConnection();

=head1 ENVIRONMENT

Debug log statements with with $ENV{'Net_FTP_Brute_loglevel'} = 5000.
Defaults to ERROR.

=head1 SUBROUTINES/METHODS

=head2 new

    my $brute = Net::FTP::Brute->new(%netFtpOptions);

Creates a new Net::FTP::Brute-object.

@PARAM1 HASH of Net::FTP->new() options.
        You also must pass the authentication parameters here:
            Host     => ftp.btj.fi,
            Port     => 21,
            Login    => username,
            Password => 1234,
            Passive  => 1,

=cut

sub new {
    my ($class, %netFtpOptions) = @_;
    my $self = {_netFtpOptions => \%netFtpOptions};
    bless($self, $class);
    return $self;
}

=head2 getWorkingConnection

    my $netFtp = $brute->getWorkingConnection($forks, $retries);

Does it's darnest to get a working connection through a corporate firewall.

@RETURNS Net::FTP-connection object

=cut

sub getWorkingConnection {
    my ($self) = @_;
    my $netFtpOptions = $self->_getNetFtpOptions();

    my $ftp;
    try {
        TRACE "Trying _testConnection()";
        $ftp = $self->_testConnection( $netFtpOptions );
    } catch {
        croak $_ unless $_ =~ /Cannot get a DATA channel open/;

        DEBUG "DATA channel not open. Escalating to brute-force.";
        my $children = $self->_spawnForks( $netFtpOptions );
        TRACE "Children spawned";

        ##Wait for children to terminate and retry connecting to ftp
        my $i = 0;
        while (@$children) {
            my $ei = $i % scalar(@$children); #Get the effective index in a very long running loop
            unless (kill(0, $children->[$ei])) { #Remove the exited child
                TRACE "Child ".$children->[$ei]." exited naturally";
                splice(@$children, $ei, 1);
            }
            try {
                TRACE "Retrying _testConnection()";
                $ftp = $self->_testConnection( $netFtpOptions );
            } catch {
                croak $_ unless $_ =~ /Cannot get a DATA channel open/;
            };
            last if $ftp;
        }
        foreach my $pid (@$children) {
            kill('SIGTERM', $pid); #Terminate children after having made a successful connection
            TRACE "Kill 'SIGTERM' Child $pid";
        }
    };

    DEBUG "Returning a working ftp-connection" if $ftp;
    DEBUG "Returning no ftp-connection" unless $ftp;
    return $ftp;
}

=head3 _spawnForks

Spawns parallel forks to try to connect to the ftp-server.

@RETURNS ARRAYRef of Integers, child process ids.

=cut

sub _spawnForks {
    my ($self, $netFtpOptions) = @_;
    my @children;
    for my $i (1..5) {
        my $pid = fork();
        if ($pid == 0) { #This is a child process
            DEBUG "Child $$ forked";
            try {
                my $ftp = $self->_testConnection( $netFtpOptions );
                DEBUG "Child $$ succesfully connected";
                exit(0);
            } catch {
                TRACE "Child $$ failed to connect: $_";
            };
        }
        else {
            push(@children, $pid);
        }
    }
    return \@children;
}

=head3 _testConnection

=cut

sub _testConnection {
    my ($self, $netFtpOptions) = @_;

    my $ftp = Net::FTP->new(%$netFtpOptions)
        or croak "Cannot connect to '".$netFtpOptions->{Host}."': $@";

    $ftp->login($netFtpOptions->{Login},$netFtpOptions->{Password})
        or croak "Cannot login to '".$netFtpOptions->{Host}."': ".$ftp->message;

    my $files = $ftp->ls();
        croak "Cannot get a DATA channel open to '".$netFtpOptions->{Host}."': ".$ftp->message unless $files;

    return $ftp;
}

=head3 _getNetFtpOptions

=cut

sub _getNetFtpOptions {
    return $_[0]->{_netFtpOptions};
}

=head1 AUTHOR

Olli-Antti Kivilahti, C<< <olli-antti.kivilahti at jns.fi> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-ftp-brute at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-FTP-Brute>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::FTP::Brute


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-FTP-Brute>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-FTP-Brute>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-FTP-Brute>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-FTP-Brute/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Olli-Antti Kivilahti.

                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Net::FTP::Brute
