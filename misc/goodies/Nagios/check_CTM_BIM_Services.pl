#!/usr/bin/perl
#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : check de l'etat d'un ou de plusieurs services du BIM Control-M
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : Nagios/Centreon
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 23/04/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE
#   ./check_CTM_BIM_Services.pl
#
# CODES RETOUR
#   Centreon : 0 -> OK, 1 -> WARNING, 2 -> CRITICAL, 3 -> UNKNOWN
#
# OPTIONS ET PARAMETRES
#   ./check_CTM_BIM_Services_Services.pl --h
#   (affiche l'aide)
#   ./check_CTM_BIM_Services.pl --a
#   (a propos de)
#
# DEPENDANCES
#   - modules :
#       - ControlM::EM::InterfaceViaDBMS (version >= 0.15)
#       - Getopt::Long
#       - Data::Dumper
#
# EXEMPLE D'UTILISATION
#   ./check_CTM_BIM_Services.pl -s mon_service -w 'Warning:1,Completed Late:1' -c 'Error:1' -h mon_sgbd -b base1 -u postgres -p 5432 -D
#==========================================================================================================

#==========================================================================================================
# Initialisation
#==========================================================================================================

#-> BEGIN

#----> ** chargement des modules **

use strict;
use warnings;
use constant {
    version => 1.0,
    nagiosOutput => ['OK', 'WARNING', 'CRITICAL', 'UNKNOWN'],
    basSvcState => ['OK', 'Completed OK', 'Error', 'Warning', 'Completed Late']
};

BEGIN: {
    checkModules(
        'ControlM::EM::InterfaceViaDBMS 0.15 qw/getStatusColorForService/',
        'Getopt::Long qw/Configure GetOptions/',
        'Data::Dumper'
    );
}

#----> ** gestion des signaux **

$SIG{'INT'} = sub {
    print "UNKNOWN - (^C)/INT detecte. Arret non prevu de la sonde.\n";
    exitIntel(3);
};

#----> ** gestion des flux standard **

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
open SAV_STDERR, '>&STDERR';

#----> ** declaration des variables globales **

my ($warning, $critical, %warning, %critical, $debug, $perfData, $serviceName, $forceOutput, $error, $timeout);
my $controlMEMVersion = 7;
my %sqlInfos = (
    'type' => 'Pg',
    'add' => undef,
    'port' => 3306,
    'base' => undef,
    'user' => 'root',
    'pass' => 'root'
);

#----> ** fonctions **

sub checkModules {
    my $error;
    for (@_) {
        eval 'use ' . $_ . ';';
        $error .= $_ . ', ' if ($@);
    }
    if ($error) {
        $error =~ s/..$//;
        print "UNKNOWN - impossible de charger le ou les modules '" . $error . "'.\n";
        exit 3;
    }
    return 1;
}

sub exitIntel($) {
    my $output = shift;
    if (defined $forceOutput && $output =~ /^\d+$/) {
        exit $forceOutput ;
    } elsif ($output  =~ /^\d+$/) {
        exit $& ;
    } else {
        exit 0 ;
    }
}

sub pluginOutput($$) {
    my ($mess, $output_code) = @_;
    if (defined $forceOutput ) {
        print uc((nagiosOutput)->[$forceOutput]) . ' - ' . $mess ;
        exitIntel((nagiosOutput)->[$forceOutput]);
    } else {
        print uc((nagiosOutput)->[$output_code]) . ' - ' . $mess;
        exitIntel($output_code);
    }
}

sub printUsage {
    my $arg = shift;
    unless (tell SAV_STDERR == -1) {
        close STDERR;
        open STDERR, '>&SAV_STDERR';
    }
    unless (defined $arg) {
        print STDERR <<TXT;
    $0 [--h, --help] [--a, --about] [--v, --version]
TXT
        exitIntel(3);
    } elsif ($arg == 1) {
        print <<TXT;
    $0
        -s, -S    <nom du service a verifier>
            '%' est le caractere joker
        -w, -W    <chaine WARNING>
            /^(OK|Completed OK|Error|Warning|Completed Late):\\d+\$\/ separes par des virgules si plusieurs etats doivent etre specifies
        -c, -C    <chaine CRITICAL>
            /^(OK|Completed OK|Error|Warning|Completed Late):\\d+\$\/ separes par des virgules si plusieurs etats doivent etre specifies
        [-v, -V]    <version du ControlMEM>
            par defaut : '$controlMEMVersion'
        [-t]    <Pg|Oracle|mysql|Sybase|ODBC>
            par defaut : '$sqlInfos{'type'}'
        -h, -H    <adresse du SGBD du ControlMEM>
        [-p]    <port du SGBD>
            par defaut : '$sqlInfos{'port'}'
        -b, -B    <base SQL>
        [-u, -U]    <utilisateur SQL>
            par defaut : '$sqlInfos{'user'}'
        [-P]    <mot de passe SQL>
            par defaut : '$sqlInfos{'pass'}'
        [-T]    <timeout en seconde de la tentative de connexion au SGBD>
            pas de timeout par defaut
        [-d]
            active le mode debug.
        [-D]
            active la generation des donnees de performance
        [-r, -R]    <0|1|2|3>
            si possible, force le code retour de la sonde
TXT
    } elsif ($arg == 2) {
        print <<TXT;
@{[version]}
TXT
    } elsif ($arg == 3) {
        print <<TXT;
    Sonde \@DSI-DOS-OIP-RUN pour les systemes compatibles Nagios
    Check de l'etat d'un ou de plusieurs services du BIM Control-M
    Version @{[version]} (stable)
    En cas de bug -> 'ylegarff.exterieur\@dcnsgroup.com'
TXT
    }
    exitIntel(0);
}

#----> ** principale **

printUsage() unless (defined $ARGV[0]);
if ($ARGV[0] =~ /^--(h|help)$/i) {
    $ARGV[1] ? printUsage() : printUsage(1);
} elsif ($ARGV[0] =~ /^--(v|version)$/i) {
    $ARGV[1] ? printUsage() : printUsage(2);
} elsif ($ARGV[0] =~ /^--(a|about)$/i) {
    $ARGV[1] ? printUsage() : printUsage(3);
}
for (my $i=0;$i<=@ARGV;$i+=2) {
    if (defined $ARGV[$i] && $ARGV[$i] =~ /^-d$/i) {
        $i++;
        next;
    }
    if (defined $ARGV[$i+2]) {
        printUsage() unless ($ARGV[$i+2] =~ /^-[a-z]{1}$/i || $ARGV[$i+2] eq '');
    }
}
printUsage() if ($ARGV[0] =~ /^--.*$/);
open STDERR, '>/dev/null' || pluginOutput("impossible de rediriger SDTERR vers '/dev/null' (erreur Perl : '" . $! . "').\n", 3);
Configure('bundling', 'no_auto_abbrev');
GetOptions(
    's|S:s' => \$serviceName,
    'w|W:s' => \$warning,
    'c|C:s' => \$critical,
    'v|V:s' => \$controlMEMVersion,
    't:s' => \$sqlInfos{'type'},
    'h|H:s' => \$sqlInfos{'add'},
    'p:s' => \$sqlInfos{'port'},
    'b|B:s' => \$sqlInfos{'base'},
    'u|U:s' => \$sqlInfos{'user'},
    'P:s' => \$sqlInfos{'pass'},
    'T:s' => \$timeout,
    'd:s' => \$debug,
    'D:s' => \$perfData,
    'r|Rs' => \$forceOutput
) || printUsage();
close STDERR;
open STDERR, '>&SAV_STDERR';
printUsage() if ($serviceName eq '');
printUsage() unless (defined $warning && defined $critical);
for (split /,/, $warning) {
    my ($status, $threshold) = split /:/;
    printUsage() unless ($threshold =~ /^\d+$/ && grep /^${status}$/, @{(basSvcState)});
    $warning{$status} = $threshold;
}
for (split /,/, $critical) {
    my ($status, $threshold) = split /:/;
    printUsage() unless ($threshold =~ /^\d+$/ && grep /^${status}$/, @{(basSvcState)});
    $critical{$status} = $threshold;
}
printUsage() unless (keys %warning && keys %critical);
printUsage() unless ($controlMEMVersion =~ /^[678]$/);
printUsage() if (defined $timeout && $timeout !~ /^\d+$/);
printUsage() unless ($sqlInfos{'type'} =~ /^(Pg|Oracle|mysql|Sybase|ODBC)$/);
printUsage() unless (defined $sqlInfos{'add'} && $sqlInfos{'add'} ne '');
printUsage() unless ($sqlInfos{'port'} =~ /^\d{1,5}$/);
printUsage() unless (defined $sqlInfos{'base'} && $sqlInfos{'base'} ne '');
printUsage() if ($sqlInfos{'user'} eq '');
printUsage() if ($sqlInfos{'pass'} eq '');
if (defined $debug) {
    $debug eq '' ? $debug = 1 : printUsage();
} else {
    $debug = 0;
}
if (defined $perfData) {
    $perfData eq '' ? $perfData = 1 : printUsage();
} else {
    $perfData = 0;
}
printUsage() if (defined $forceOutput && $forceOutput !~ /^[0123]$/);

#->

my $BIMSession = ControlM::EM::InterfaceViaDBMS->newSession(
    'ctmEMVersion' => $controlMEMVersion,
    'DBMSType' => $sqlInfos{'type'},
    'DBMSAddress' => $sqlInfos{'add'},
    'DBMSPort' => $sqlInfos{'port'},
    'DBMSInstance' => $sqlInfos{'base'},
    'DBMSUser' => $sqlInfos{'user'},
    'DBMSPassword' => $sqlInfos{'pass'},
    'DBMSTimeout' => $timeout
);

$BIMSession->connectToDB() || pluginOutput($BIMSession->getError() . "\n", 3);

my $services = $BIMSession->getCurrentServices(
    'matching' => $serviceName
);

unless (defined ($error = $BIMSession->getError())) {
    if (my @servicesKeys = keys %{$services}) {
        my ($nbWarning, $nbCritical);
        my %stateCount = map { $_ => 0 } @{(basSvcState)};
        print Dumper($services) . "\n" if ($debug);
        $stateCount{getStatusColorForService($services->{$_})}++ for (@servicesKeys);
        for (keys %stateCount) {
            $nbWarning++ if (exists $warning{$_} && $stateCount{$_} >= $warning{$_});
            $nbCritical++ if (exists $critical{$_} && $stateCount{$_} >= $critical{$_});
        }
        my $perfDataString = ($perfData ? ' | OK=' . $stateCount{'OK'} . ',Completed OK=' . $stateCount{'Completed OK'} . ',Error=' . $stateCount{'Error'} . ',Warning=' . $stateCount{'Warning'} . ',Completed Late=' . $stateCount{'Completed Late'} : '.' ) . "\n";
        if ($nbWarning && $nbCritical) {
            pluginOutput("les seuils WARNING ('" . $warning . "') et CRITICAL ('" . $critical . "') ont ete franchis '" . $nbWarning . "' et '" . $nbCritical . "' fois pour les services '" . $serviceName . "'" . $perfDataString, 2);
        } elsif ($nbCritical) {
            pluginOutput("le seuil CRITICAL ('" . $critical . "') a ete franchi '" . $critical . "' fois pour les services '" . $serviceName . "'" . $perfDataString, 2);
        } elsif ($nbWarning) {
            pluginOutput("le seuil WARNING ('" . $warning . "') a ete franchi '" . $critical . "' fois pour les services '" . $serviceName . "'" . $perfDataString, 1);
        } else {
            pluginOutput("tous les services '" . $serviceName . "' sont OK vis-a-vis des seuils WARNING ('" . $warning . "') et CRITICAL ('" . $critical . "')" . $perfDataString, 0);
        }
    } else {
        pluginOutput("aucun service avec comme nom '" . $serviceName . "' n'a ete trouve" . ($perfData ? ' | OK=0,Completed OK=O,Error=0,Warning=0,Completed Late=0' : '.') . "\n", 3);
    }
} else {
    pluginOutput($error . "\n", 3);
}

#-> END

__END__

=pod

=head1 NOM

    check_CTM_BIM_Services.pl

=head1 SYNOPSIS

    Sonde Nagios de l etat d'un ou de plusieurs services du BIM Control-M

=head1 DEPENDANCES

    ControlM::EM::InterfaceViaDBMS (version >= 0.15), GetOpt::Long, Data::Dumper

=head1 USAGE

    ./check_CTM_BIM_Services.pl

=head1 PARAMETRES PRINCIPAUX

    ./check_CTM_BIM_Services.pl --h
    (affiche l'aide)
    ./check_CTM_BIM_Services.pl --a
    (a propos de)
    ./check_CTM_BIM_Services.pl --v
    (affiche la version)

=head1  EXEMPLE D UTILISATION

    ./check_CTM_BIM_Services.pl -s mon_service -w 'Warning:1,Completed Late:1' -c 'Error:1' -h mon_sgbd -b base1 -u postgres -p 5432 -D

=head1 INFORMATIONS COMPLEMENTAIRES

    Sonde Nagios developpe par Yoann Le Garff.

=cut