#!/usr/bin/perl

use strict;
use warnings;
use ControlM::EM::InterfaceViaDBMS 0.15 qw/$VERSION getStatusColorForService/;
use Data::Dumper;

$\ = "\n";

# -------------------------------------------------------------------------------------

# print $VERSION;

# -------------------------------------------------------------------------------------

my $err;

my $session = ControlM::EM::InterfaceViaDBMS->new(
    'ctmEMVersion' => 7,
    'DBMSType' => 'mysql',
    'DBMSAddress' => 'shl90062',
    'DBMSPort' => 5432,
    'DBMSInstance' => 'pcme01nt',
    'DBMSPassword' => 'ctmpass',
    'DBMSUser' => 'emuser',
    'DBMSTimeout' => 5,
    'verbose' => 1
);

# -------------------------------------------------------------------------------------

print Dumper($session) . "\n-------------------------------------------------------------------------------------\n";

print "setPublicProperty('DBMSType', 'Pg'), retourne : " . $session->setPublicProperty('DBMSType', 'Pg') . ".\n";

print Dumper($session) . "\n-------------------------------------------------------------------------------------\n";

# -------------------------------------------------------------------------------------

$session->connectToDB() || die $session->getError();

my $services = $session->getCurrentServices(
    'matching' => '%'
);

unless (defined ($err = $session->getError())) {
    print $_->{'service_name'} . ' : ' . getStatusColorForService($_) . ' : ' . $_->{'description'} for (values %{$services})
} else {
    die $err;
}

# -------------------------------------------------------------------------------------

# print $session->getSessionIsAlive();

# print $session->getSessionIsConnected();

# $session->disconnectFromDB();

# print $session->getSessionIsAlive();

# print $session->getSessionIsConnected();

# --------------------------------------------------------------------------------------

print "\n-------------------------------------------------------------------------------------\n";

my $workOn = $session->workOnCurrentServices();

die $session->getError() if ($session->getError());

my $xmlStrRef = $workOn->getSOAPEnvelopeForServices();

die $session->getError() if ($session->getError());

print ${$workOn->getSOAPEnvelopeForServices()} . "\n";