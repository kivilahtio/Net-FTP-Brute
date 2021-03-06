package Net::FTP::Brute;

use Modern::Perl '2014';
use warnings FATAL => 'all';
use Carp;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{'Net_FTP_Brute_loglevel'} || $ERROR);

use Net::FTP;
use POSIX ":sys_wait_h";


use Net::FTP::Brute::Exception::Login;
use Net::FTP::Brute::Exception::Connection;
use Net::FTP::Brute::Exception::DATA;


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
If cannot establish a connection, retries $retries times.
If cannot establish a DATA-connection, tries to brute-force a working connection $retries times.
If cannot login using the supplied credentials, throws an exception.

@PARAM1 Integer, how many parallel threads as maximum to fork to "stimulate" the remote ftp-server/firewall.
        Defaults to 1-5
@PARAM2 Integer, how many times to try brute-forcing before giving up?
        Defaults to 100
@RETURNS Net::FTP-connection object

@THROWS Net::FTP::Brute::Exception::Connection, if no connection to the ftp-server cannot be made
@THROWS Net::FTP::Brute::Exception::Login, if user authentication fails
@THROWS Net::FTP::Brute::Exception::DATA, if a DATA-connection cannot be established

=cut

sub getWorkingConnection {
    my ($self, $forks, $retries) = @_;
    $forks = 5 unless $forks;
    $retries = ($retries) ? $retries++ : 101;
    my $netFtpOptions = $self->_getNetFtpOptions();
    return $self->_recurseConnectionRecovery($forks, $retries, $netFtpOptions);
}

=head3 _recurseConnectionRecovery

Main recursion loop to try to establish a working connection

=cut

sub _recurseConnectionRecovery {
    my ($self, $forks, $retries, $netFtpOptions) = @_;
    TRACE "PID$$: Recursing _recurseConnectionRecovery($forks, $retries, $netFtpOptions)";
    $self->_activeException()->rethrow() unless $retries; #Kill the recursion

    my $ftp;
    try {
        TRACE "PID$$: Trying _testConnection()";
        $ftp = $self->_testConnection( $netFtpOptions );
    } catch {
        croak($_) unless(blessed($_));
        $self->_activeException($_);

        ##Data connection failed, start brute-forcing
        if ($_->isa('Net::FTP::Brute::Exception::DATA')) {
            $self->_recoverUsingBruteForce($forks, $netFtpOptions);
        }
        ##Connection failed/timed out. Retry without brute forcing until the connection has come back.
        elsif ($_->isa('Net::FTP::Brute::Exception::Connection')) {
            DEBUG "PID$$: Connection failed. Retrying peacefully.";
        }
        else {
            $_->rethrow(); #a fatal Exception, terminate the module.
        }
    };

    DEBUG "PID$$: Returning a working ftp-connection" if $ftp;
    DEBUG "PID$$: Returning no ftp-connection" unless $ftp;
    return $ftp || $self->_recurseConnectionRecovery($forks, --$retries, $netFtpOptions);
}

=head3 _recoverUsingBruteForce

On this connection retry-loop, try brute-forcing a DATA-connection

@RETURNS Net::FTP-connection or undef

=cut

sub _recoverUsingBruteForce {
    my ($self, $forks, $netFtpOptions) = @_;
    DEBUG "PID$$: DATA connection not open. Escalating to brute-force.";
    my @children = $self->_spawnForks( $forks, $netFtpOptions );
    TRACE "PID$$: Children spawned";

    my $ftp;
    ##Wait for children to terminate and retry connecting to ftp
    my $i = 0;
    while (@children) {
        try {
            TRACE "PID$$: Retrying _testConnection()";
            $ftp = $self->_testConnection( $netFtpOptions );
        } catch {
            croak($_) unless(blessed($_));
            $self->_activeException($_);
        };
        last if $ftp;
        $i++;

        $self->_handleExitedChilds(\@children);
    }
    foreach my $pid (@children) {
        kill('SIGTERM', $pid); #Terminate children after having made a successful connection
        TRACE "PID$$: Kill 'SIGTERM' Child $pid";
    }
    $self->_handleExitedChilds(\@children);

    return $ftp;
}

=head3 _spawnForks

Spawns parallel forks to try to connect to the ftp-server.

@RETURNS ARRAY of Integers, child process ids.

=cut

sub _spawnForks {
    my ($self, $forks, $netFtpOptions) = @_;
    my @children;
    for my $i (1..$forks) {
        my $pid = fork();
        if ($pid == 0) { #This is a child process
            DEBUG "Child $$ forked";
            try {
                my $ftp = $self->_testConnection( $netFtpOptions );
                DEBUG "Child $$ succesfully connected";
            } catch {
                TRACE "Child $$ failed to connect: $_";
            };
            exit(0);
        }
        else {
            push(@children, $pid);
        }
    }
    return @children;
}

=head3 _handleExitedChilds

Collect exited child processes so they wont be left defunct.

=cut

sub _handleExitedChilds {
    my ($self, $children) = @_;

    for (my $i=0 ; $i<scalar(@$children) ; $i++) {
        my $pid = $children->[$i];
        my $kid = waitpid($pid, WNOHANG); #Do we get a signal from the child process $pid?
        if ($kid == $pid) {
            TRACE "PID$$: Child $pid exited";
            splice(@$children, $i--, 1);
        }
        elsif ($kid < 0) {
            TRACE "PID$$: Child $pid no longer exists";
        }
        elsif ($kid == 0) {
            TRACE "PID$$: Child $pid still running";
        }
        else {
            TRACE "PID$$: Child $pid unknown process status '$kid'";
            splice(@$children, $i--, 1);
        }
    }

    return;
}

=head3 _testConnection

Makes a connection to the ftp-server using Net::FTP and tests the DATA-connection
using "ls" aka. "dir".

@THROWS Net::FTP::Brute::Exception::Connection
@THROWS Net::FTP::Brute::Exception::Login
@THROWS Net::FTP::Brute::Exception::DATA

=cut

sub _testConnection {
    my ($self, $netFtpOptions) = @_;

    my $ftp = Net::FTP->new(%$netFtpOptions)
        or Net::FTP::Brute::Exception::Connection->throw(Host => $netFtpOptions->{Host},
                                                         Port => $netFtpOptions->{Port},
                                                         error => $@);

    $ftp->login($netFtpOptions->{Login},$netFtpOptions->{Password})
        or Net::FTP::Brute::Exception::Login->throw(Host => $netFtpOptions->{Host},
                                                    Port => $netFtpOptions->{Port},
                                                    Login => $netFtpOptions->{Login},
                                                    error => $ftp->message());

    my $files = $ftp->ls();
        Net::FTP::Brute::Exception::DATA->throw(Host => $netFtpOptions->{Host},
                                                Port => $netFtpOptions->{Port},
                                                error => $ftp->message())
        unless $files;

    return $ftp;
}

=head3 _getNetFtpOptions

=cut

sub _getNetFtpOptions {
    my ($self) = @_;
    return $self->{_netFtpOptions};
}

=head3 _activeException

Gets or sets the latest Exception caught.

=cut

sub _activeException {
    my ($self, $exception) = @_;
    return $self->{_activeException} unless $exception;
    return $self->{_activeException} = $exception;
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
