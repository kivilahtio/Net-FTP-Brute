#!perl
use Modern::Perl '2014';
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::FTP::Brute',
    license             => 'artistic_2',
    dist_author         => q{Olli-Antti Kivilahti <olli-antti.kivilahti@jns.fi>},
    dist_version_from   => 'lib/Net/FTP/Brute.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More'    => 0,
    },
    requires => {
        'Net::FTP'      => 3.0,
        'Moo'           => 2.0,
        'Log::Log4perl' => 1.47,
    },
    add_to_cleanup     => [ 'Net-FTP-Brute-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

1;
