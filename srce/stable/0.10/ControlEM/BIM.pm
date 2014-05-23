#!/usr/bin/perl
#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Module pour consultation du Batch Impact Manager (BIM) ControlM 7/8
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlM EM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 17/03/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE
#   perl -e 'use ControlEM::BIM;'
#
# DEPENDANCES OBLIGATOIRES
#   - 'Exporter'
#   - 'Time::Local'
#   - 'POSIX'
#   - 'DBI'
#   - 'DBD::(Pg|mysql|Oracle|Sybase|ODBC)'
# ATTENTION
#   Ce module se base en partie sur l'heure du systeme qui le charge. Si celle ci est fausse, certains resultats se retrouveront faux.
# AIDE
#   perldoc BIM.pm
#==========================================================================================================

#-> BEGIN

#-> POD (Plain Old Documentation)

=pod

=encoding utf-8

=head1 NOM

ControlEM::BIM

=head1 SYNOPSIS

Module pour consultation du Batch Impact Manager (BIM) ControlM 7/8

=head1 DEPENDANCES

Exporter, Time::Local, POSIX, DBI, /^DBD::(Pg|mysql|Oracle|Sybase|ODBC)$/

=head1 CHARGEMENT

use ControlEM::BIM;

=head1 FONCTIONS PUBLIQUES

=over

=item - getStatusForServiceState($)

Cette fonction permet de convertir le champ 'state' de la hashtable générée par les methodes getCurrentServices() ou getOlderServices() en un status clair et surtout compréhensible ('Ok', 'CompletedWOk', 'CompletedLate', 'Warning', 'Error').

=item - getNbSessionsInstanced()

Renvoie le nombre d'instances de la classe BIM en cours.

=item - getNbSessionsConnected()

Renvoie le nombre d'instances de la classe BIM en cours et connectées à la base du ControM EM.

=back

=head1 METHODES PUBLIQUES

=over

=item - my $sesion = ControlEM::BIM->newSession($$$$$$)

Cette méthode est le constructeur de la classe BIM. Pour information, le destructeur DESTROY() est appelé lorsque toutes les références a l'objet instancié ont été détruitres ('undef($obj);' par exemple).

=item - $session->connectToDB()

Cette méthode permet de se connecter à la base du Control EM avec les paramètres fournis au constructeur newSession().

=item - $session->disconnectFromDB()

Cette méthode permet de se déconnecter de la base du Control EM mais elle n'apelle pas le destructeur DESTROY().

=item - $session->getCurrentServices()

Cette méthode retourne une référence de la hashtable de la liste des services en cours dans le Batch Impact Manager (BIM). La clé est 'log_id'.
Il est possible de ne retourner que les services avec un nom respectant une condition de type LIKE (SQL LIKE CLAUSE), la clause est alors à renseigner dans via le premier paramètre de cette méthode.

=item - $session->countCurrentServices()

Cette méthode retourne le nombre de services actuellement en cours dans le Batch Impact Manager (BIM). Elle dérive de la méthode $session->getCurrentServices().

=item - $session->getError()

Retourne la dernière erreur générée.
Retourne 'undef()' si aucune erreur n'est présente ou si la dernière a été nettoyée via la méthode $session->clearError().

=item - $session->clearError()

Remplace la valeur de la dernière erreur générée par 'undef()'.

=item - $session->getSessionIsAlive()

Vérifie et retourne l'état (booléen) de la connexion à la base du Control EM. Attention, cette méthode n'est pas fiable pour tous les types de SGBD, voir http://search.cpan.org/dist/DBI/DBI.pm#ping

=item - $session->getSessionIsConnected()

Retourne l'état (booléen) de la connexion à la base du Control EM.

=back

=head1 PROPRIETES PUBLIQUES (directement manipulables sans accesseurs/modificateurs)

=over

=item - $session->{'CtmEMVersion'}

Version du ControlM EM auquel se connecter.
Les valeurs acceptées sont 7 et 8.

=item - $session->{'DBMSType'}

Type de SGBD du ControlM EM auquel se connecter.
Les valeurs acceptées sont 'Pg', 'Oracle', 'mysql', 'Sybase' et 'ODBC'. Pour une connexion à MS SQL Server, les drivers 'Sybase' et 'ODBC' fonctionnent.

=item - $session->{'DBMSAddress'}

Adresse du SGBD du ControlM EM auquel se connecter.

=item - $session->{'DBMSPort'}

Port du SGBD du ControlM EM auquel se connecter.

=item - $session->{'DBMSInstance'}

Instance (ou base) du SGBD du ControlM EM auquel se connecter.

=item - $session->{'DBMSUser'}

Utilisateur du SGBD du ControlM EM auquel se connecter.

=item - $session->{'DBMSPassword'}

Mot de passe du SGBD du ControlM EM auquel se connecter.

=item - $session->{'DBMSTimeout'}

Timeout (en seconde) de la tentavive de connexion au SGBD du ControlM EM.
La valeur 0 signifie qu'aucun timeout ne sera appliqué.
ATTENTION, cette propriété risque de ne pas fonctionner sous Windows (ou d'autres systèmes ne gérant pas les signaux UNIX).

=back

=head1 EXEMPLES

=over

=item - Afficher la version du module :

    #!/usr/bin/perl

    use ControlEM::BIM qw($VERSION);

    print($VERSION);

=item - Initialiser une session au Batch Impact Manager (BIM) du ControlM EM, s'y connecter et afficher le nombre de services courants :

    #!/usr/bin/perl

    use ControlEM::BIM;

    my $err;

    my $session = ControlEM::BIM->newSession(
        'CtmEMVersion' => 7,
        'DBMSType' => 'Pg',
        'DBMSAddress' => '127.0.0.1',
        'DBMSPort' => 3306,
        'DBMSInstance' => 'controlm_em',
        'DBMSUser' => 'root',
        'DBMSPassword' => 'root'
    ); # les paramètres disponibles sont 'CtmEMVersion', 'DBMSType', 'DBMSAddress', 'DBMSPort', 'DBMSInstance', 'DBMSUser', 'DBMSPassword' et 'DBMSTimeout'

    $session->connectToDB() || die($session->getError());

    my $nbServices = $sesion->countCurrentServices();

    $err = $session->getError();

    defined($err) ? die($err) : print('Il y a ' . $nbServices . "courants.\n");

=item - Initialiser plusieurs sessions :
    #!/usr/bin/perl

    use ControlEM::BIM qw(getNbSessionsInstanced);

    my %sessionParams = (
        'CtmEMVersion' => 7,
        'DBMSType' => 'Pg',
        'DBMSAddress' => '127.0.0.1',
        'DBMSPort' => 3306,
        'DBMSInstance' => 'controlm_em',
        'DBMSUser' => 'root',
        'DBMSPassword' => 'root'
    );

    my $session1 = ControlEM::BIM->newSession(%sessionParams);
    my $session2 = ControlEM::BIM->newSession(%sessionParams);

    print(getNbSessionsInstanced()) # affiche '2'

=item - Recuperer la liste des noms de service actuellement en cours dans le Batch Impact Manager (BIM) du ControlM EM :
    #!/usr/bin/perl

    use ControlEM::BIM;

    my $err;

    my $session = ControlEM::BIM->newSession(
        'CtmEMVersion' => 7,
        'DBMSType' => 'Pg',
        'DBMSAddress' => '127.0.0.1',
        'DBMSPort' => 3306,
        'DBMSInstance' => 'controlm_em',
        'DBMSUser' => 'root',
        'DBMSPassword' => 'root'
    );

    $session->connectToDB() || die($session->getError());

    my $servicesHashRef = $session->getCurrentServices();

    $err = $session->getError()

    unless (defined($err)) {
        for (values(%{$servicesHashRef}) { # la clé correspond a la propriete 'log_id'
            print($_->{'service_name'} . "\n"); # les proprietes disponibles sont 'order_id', 'data_center', 'service_name', 'order_time', 'description' et 'status_final'
        }
    } else {
        die($err));
    }

=back

=head1 ATTENTION

Ce module se base en partie sur l'heure du systeme qui le charge. Si celle ci est fausse, certains resultats se retrouveront faux.

=head1 REMARQUES

=over

=item - Il faudrait se baser sur l'heure du ControlM EM pour les calculs si cette donnée est disponible sur sa base de données.

=item - Porter le module sous le framework Moose serait une solution pour notamment éviter la modification des 'attributs privées' critiques (exemple : $session->{__DBI}) de l'objet par l'utilisateur du module.

=back

=head1 INFORMATIONS COMPLEMENTAIRES

Module développé par Yoann Le Garff.

=cut


#----> **initialisation**

use strict;
use warnings;

{
    #----> **initialisation de la classe**

    package ControlEM::BIM;

    use Exporter;
    use Time::Local;
    use POSIX qw(strftime :signal_h);
    use DBI;
    # use Data::Dumper;

    #----> **variables de classe**

    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw($VERSION getStatusForServiceState getNbSessionsInstanced getNbSessionsConnected);
    our $AUTOLOAD;
    our $VERSION = 0.10;

    my %__sessionsState = (
        'nbSessionsInstanced' => 0,
        'nbSessionsConnected' => 0
    );

    my %__statusForServiceState = (
        'Ok' => ['service is running'],
        'CompletedWOk' => ['service completed'],
        'CompletedLate' => ['service completed late'],
        'Warning' => ['job finished too quickly', 'job finished early'],
        'Error' => ['service is late', 'job failure on service path', 'job ran too long']
    );

    #----> **fonctions publiques**

    sub getStatusForServiceState($) {
        my $bimOutput = shift();
        for (keys(%__statusForServiceState)) {
            if (grep(/^$bimOutput$/i, @{$__statusForServiceState{$_}})) {
                return($_);
            }
        }
        return(0);
    }

    sub getNbSessionsInstanced {
        return($__sessionsState{'nbSessionsInstanced'});
    }

    sub getNbSessionsConnected {
        return($__sessionsState{'nbSessionsConnected'});
    }

    #----> **fonctions privees**

    my $__myOSisUnix = sub {
        my @unixBasedOperatingSystems = (
            'aix', 'bsdos', 'dgux', 'dynixptx', 'freebsd', 'linux', 'hpux', 'irix', 'openbsd', 'dec_osf', 'svr4', 'sco_sv',
            'svr4', 'unicos', 'unicosmk', 'solaris', 'sunos', 'netbsd', 'sco3', 'ultrix', 'macos', 'rhapsody'
        );
        grep(/^$^O$/i, @unixBasedOperatingSystems) ? return(1) : return(0);
    };

    my $__dateToPosixTimestamp = sub {
        my ($year, $mon, $day, $hour, $min, $sec) = split(/[\/\-\s:]+/, shift());
        my $time = timelocal($sec, $min, $hour, $day, $mon - 1 ,$year);
        ($time =~ /^\d+$/) ? return($time) : return(0);
    };

    my $__doesTablesExists = sub {
        my ($dbh, @tablesName) = @_;
        for (@tablesName) {
            my $sth = $dbh->table_info(undef(), 'public', $_, 'TABLE');
            if ($sth->execute()) {
                my @tableInfos = $sth->fetchrow_array();
                # $sth->finish(); # p-e inutile voir a enlever, puisque DBI appelle probablement cette methode si il n'y a plus aucune ligne a rapporter
                return(1, 0) unless (@tableInfos);
            } else {
                return(0, 0);
            }
        }
        return(1, 1);
    };

    my $__getDatasCentersInfos = sub {
        my ($dbh, $dataCenterName) = @_;
        my $sth = $dbh->prepare(<<SQL);
            SELECT data_center, ctm_daily_time, enabled
            FROM comm
            WHERE data_center LIKE '$dataCenterName';
SQL
        if ($sth->execute()) {
            my $str = $sth->fetchall_hashref('data_center');
            keys(%{$str}) ? return(1, $str) : return(1, 0);
        } else {
            return(0, 0);
        }
    };

    my $__getAllServices = sub {
        my ($dbh, $sqlLikeSearchPattern) = @_;
        my $sth = $dbh->prepare(<<SQL);
            SELECT log_id, order_id, data_center, service_name, order_time, description, status_final
            FROM bim_log
            WHERE log_id IN (
                SELECT MAX(log_id)
                FROM bim_log
                GROUP BY order_id
            )
            AND service_name LIKE '$sqlLikeSearchPattern'
            ORDER BY service_name;
SQL
        if ($sth->execute()) {
            return(1, $sth->fetchall_hashref('log_id'));
        } else {
            return(0, 0);
        }
    };

    my $__calculStartEndDayTimeInPosixTimestamp = sub {
        my ($ctmDailyTime, $previousNextOrAll) = @_;
        if ($ctmDailyTime =~ /^[\+\-]\d{4}$/) {
            # ctmDailyTime, le + ou - n'est pas pris en compte pour le moment, faute de precisions (champ 'DAYTIME' dans le ControlM Configuration Manager)
            my ($ctmDailyHour, $ctmDailyMin) = unpack('(a2)*', substr($ctmDailyTime, 1, 4));
            my $time = time();
            my ($minNow, $hoursNow, $dayNow, $monthNow, $yearNow) = split(/-/, strftime('%-M-%-H-%-d-%-m-%-Y', localtime($time)));
            my ($previousDay, $previousDayMonth, $previousDayYear) = split(/-/, strftime('%-d-%-m-%-Y', localtime($time - 86400)));
            my ($nextDay, $nextDayMonth, $nextDayYear) = split(/-/, strftime('%-d-%-m-%-Y', localtime($time + 86400)));
            my ($startDayTimeInPosixTimestamp, $endDayTimeInPosixTimestamp);
            if ($hoursNow >= $ctmDailyHour && $minNow >= $ctmDailyMin) {
                $startDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($yearNow . '/' . $monthNow . '/' . $dayNow . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
                $endDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($nextDayYear . '/' . $nextDayMonth . '/' . $nextDay . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
            } else {
                $startDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($previousDayYear . '/' . $previousDayMonth . '/' . $previousDay . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
                $endDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($yearNow . '/' . $monthNow . '/' . $dayNow . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
            }
            for ($previousNextOrAll) {
                /^\*$/ && return(1, $startDayTimeInPosixTimestamp, $endDayTimeInPosixTimestamp);
                /^\+$/ && return(1, $endDayTimeInPosixTimestamp);
                return(1, $startDayTimeInPosixTimestamp);
            }
        }
        return(0, 0);
    };

    #----> **methodes publiques**

    #-> constructeur


    sub newSession {
        my $class = shift();
        $class = ref($class) || $class;
        my $self = {};
        my %params = @_;
        $__sessionsState{'nbSessionsInstanced'}++;
        $self->{'__errorMessage'} = undef();
        $self->{'__sessionIsConnected'} = 0;
        if (exists($params{'CtmEMVersion'}) && exists($params{'DBMSType'}) && exists($params{'DBMSAddress'}) && exists($params{'DBMSPort'}) && exists($params{'DBMSInstance'}) && exists($params{'DBMSUser'})) {
            $self->{'CtmEMVersion'} = $params{'CtmEMVersion'};
            $self->{'DBMSType'} = $params{'DBMSType'};
            $self->{'DBMSAddress'} = $params{'DBMSAddress'};
            $self->{'DBMSPort'} = $params{'DBMSPort'};
            $self->{'DBMSInstance'} = $params{'DBMSInstance'};
            $self->{'DBMSUser'} = $params{'DBMSUser'};
            $self->{'DBMSPassword'} = exists($params{'DBMSPassword'}) ? $params{'DBMSPassword'} : undef();
            $self->{'DBMSTimeout'} = (exists($params{'DBMSTimeout'}) && $params{'DBMSTimeout'} >= 0) ? $params{'DBMSTimeout'} : 0;
        } else {
            $self->{'__errorMessage'} = "'newSession()' : un ou plusieurs parametres obligatoires ne sont pas declares.";
        }
        bless($self, $class);
        return($self);
    }

    #-> connect/disconnect

    sub connectToDB {
        my $self = shift();
        if (exists($self->{'CtmEMVersion'}) && exists($self->{'DBMSType'}) && exists($self->{'DBMSAddress'}) && exists($self->{'DBMSPort'}) && exists($self->{'DBMSInstance'}) && exists($self->{'DBMSUser'})) {
            if ($self->{'CtmEMVersion'} =~ /^[78]$/ && $self->{'DBMSType'} =~ /^(Pg|Oracle|mysql|Sybase|ODBC)$/ && $self->{'DBMSAddress'} ne '' && $self->{'DBMSPort'} =~ /^\d+$/ && $self->{'DBMSPort'} >= 0  && $self->{'DBMSPort'} <= 65535 && $self->{'DBMSInstance'} ne '' && $self->{'DBMSUser'} ne '') {
                unless ($self->getSessionIsConnected()) {
                    eval('require DBD::' . $self->{'DBMSType'});
                    unless ($@) {
                        my $myOSisUnix = $__myOSisUnix->();
                        my $ALRMDieSub = sub {
                            die("'DBI' : impossible de se connecter (timeout atteint) a la base '" . $self->{'DBMSType'} . ", instance '" .  $self->{'DBMSInstance'} . "' du serveur '" .  $self->{'DBMSType'} . "'.");
                        };
                        my $oldaction;
                        if ($myOSisUnix) {
                            my $mask = POSIX::SigSet->new(SIGALRM);
                            my $action = POSIX::SigAction->new(
                                \&$ALRMDieSub,
                                $mask
                            );
                            $oldaction = POSIX::SigAction->new();
                            sigaction(SIGALRM, $action, $oldaction);
                        } else {
                            local $SIG{'ALRM'} = \&$ALRMDieSub;
                        }
                        $self->{'__errorMessage'} = undef();
                        eval {
                            my $connectionString = 'dbi:' . $self->{'DBMSType'};
                            if ($self->{'DBMSType'} eq 'ODBC') {
                                $connectionString .= ':driver={SQL Server};server=' . $self->{'DBMSAddress'} . ',' . $self->{'DBMSPort'} . ';database=' . $self->{'DBMSInstance'};
                            } else {
                                $connectionString .= ':host=' . $self->{'DBMSAddress'} . ';database=' . $self->{'DBMSInstance'} . ';port=' . $self->{'DBMSPort'};
                            }
                            $self->{'__DBI'} = DBI->connect($connectionString,
                                $self->{'DBMSUser'},
                                $self->{'DBMSPassword'},
                                {
                                    'RaiseError' => 0,
                                    'PrintError' => 0,
                                    'AutoCommit' => 1
                                }
                            ) || do {
                                ($self->{'__errorMessage'} = "'DBI' : '" . $DBI::errstr . "'.") =~ s/\s+/ /g;
                            };
                        };
                        alarm(0);
                        sigaction(SIGALRM, $oldaction) if ($myOSisUnix);
                        return(0) if ($self->{'__errorMessage'});
                        if ($@) {
                            $self->{'__errorMessage'} = $@;
                            return(0);
                        }
                        my ($situation, $testTables) = $__doesTablesExists->($self->{'__DBI'}, 'bim_log', 'comm');
                        if ($situation) {
                            if ($testTables) {
                                # ! rajouter la verifications des champs des tables ainsi que le type de ces champs
                                $self->{'__sessionIsConnected'} = 1;
                                $__sessionsState{'nbSessionsConnected'}++;
                                return(1);
                            } else {
                                $self->{'__errorMessage'} = "'connectToDB()' : la connexion au SGBD est etablie mais une ou plusieurs tables requises sont inexistantes."
                            }
                        } else {
                            $self->{'__errorMessage'} = "'connectToDB()' : la connexion est etablie mais la ou les methodes DBI 'table_info()'/'execute()' ont echouees.";
                        }
                    } else {
                        $@ =~ s/\s+/ /g;
                        $self->{'__errorMessage'} = "'connectToDB()' : impossible de charger le module 'DBD::" . $self->{'DBMSType'} . "' : '" . $@ . "'.";
                    }
                } else {
                    $self->{'__errorMessage'} = "'connectToDB()' : impossible de se connecter car cette instance est deja connectee.";
                }
            } else {
                $self->{'__errorMessage'} = "'connectToDB()' : un ou plusieurs parametres ne sont pas valides.";
            }
        } else {
            $self->{'__errorMessage'} = "'connectToDB()' : un ou plusieurs parametres ne sont pas valides.";
        }
        return(0);
    }

    sub disconnectFromDB {
        my $self = shift();
        if ($self->{'__sessionIsConnected'}) {
            if ($self->{'__DBI'}->disconnect()) {
                $self->{'__sessionIsConnected'} = 0;
                $__sessionsState{'nbSessionsConnected'}--;
                return(1);
            } else {
                $self->{'__errorMessage'} = $self->{'__DBI'}->errstr();
            }
        } else {
            $self->{'__errorMessage'} = "'disconnectFromDB()' : impossible de clore la connexion car cette instance n'est pas connectee.";
        }
        return(0);
    }

    #-> methodes liees au Batch Impact Manager (BIM)

    sub getCurrentServices {
        my ($self, $sqlLikeSearchPattern) = @_;
        $sqlLikeSearchPattern = '%' unless (defined($sqlLikeSearchPattern));
        if ($self->getSessionIsConnected()) {
            my ($situation, $datacenterInfos) = $__getDatasCentersInfos->($self->{'__DBI'}, '%');
            if ($situation) {
                if ($datacenterInfos) {
                    my ($situation, $servicesDatas) = $__getAllServices->($self->{'__DBI'}, '%');
                    if ($situation) {
                        if (keys(%{$servicesDatas})) {
                            for (keys(%{$servicesDatas})) {
                                if ($datacenterInfos->{$servicesDatas->{$_}->{'data_center'}}->{'enabled'}) {
                                    my ($situation, $datacenterOdateStart, $datacenterOdateEnd) = $__calculStartEndDayTimeInPosixTimestamp->($datacenterInfos->{$servicesDatas->{$_}->{'data_center'}}->{'ctm_daily_time'}, '*');
                                    if ($situation) {
                                        my $ODateInTimestamp = $__dateToPosixTimestamp->($servicesDatas->{$_}->{'order_time'});
                                        unless ($ODateInTimestamp >= $datacenterOdateStart && $ODateInTimestamp <= $datacenterOdateEnd) {
                                            delete($servicesDatas->{$_});
                                        }
                                    } else {
                                        $self->{'__errorMessage'} = "'getCurrentServices()' : le champ 'ctm_daily_time' de '" . $servicesDatas->{$_}->{'data_center'} . "' n'est pas correct " . '(=~ /^[\+\-]\d{4}$/).';
                                        return(0);
                                    }
                                } else {
                                    delete($servicesDatas->{$_});
                                }
                            }
                        }
                        return($servicesDatas);
                    } else {
                        $self->{'__errorMessage'} = "'getCurrentServices()' : erreur lors de la recuperation de la liste des services : la methode DBI 'execute()' a echouee : '" . $self->{'__DBI'}->errstr() . "'.";
                    }
                } else {
                    $self->{'__errorMessage'} = "'getCurrentServices()' : il n'y a pas de ControlM Server de configurer sur ce ControlM EM.";
                }
            } else {
                $self->{'__errorMessage'} = "'getCurrentServices()' : erreur lors de la recuperation des informations a propos des ControlM Server: la methode DBI 'execute()' a echoue : '" . $self->{'__DBI'}->errstr() . "'.";
            }
        } else {
            $self->{'__errorMessage'} = "'getCurrentServices()' : impossible de faire la requete car la connexion au SGBD n'est pas active.";
        }
        return(0);
    }

    sub countCurrentServices {
        my $self = shift();
        my $getCurrentServices = $self->getCurrentServices();
        (ref($getCurrentServices) eq 'HASH') ? return(scalar(keys(%{$getCurrentServices}))) : return($getCurrentServices);
    }

    # sub getOlderServices {
        # my ($self, $sqlLikeSearchPattern) = @_;
        # return(0);
    # }

    #-> accesseurs/mutateur

    sub getError {
        my $self = shift();
        return($self->{'__errorMessage'});
    }

    sub clearError {
        my $self = shift();
        $self->{'__errorMessage'} = undef();
    }

    sub getSessionIsAlive {
        my $self = shift();
        if ($self->{'__DBI'} && $self->getSessionIsConnected()) {
            return($self->{'__DBI'}->ping());
        } else {
            $self->{'__errorMessage'} = "'getSessionIsAlive()' : impossible tester l'etat de la connexion au SGBD car celle ci n'est pas active.";
            return(0);
        }
    }

    sub getSessionIsConnected {
        my $self = shift();
        return($self->{'__sessionIsConnected'});
    }


    #-> Perl BuiltIn

    sub AUTOLOAD {
        my $self = shift();
        (my $called = $AUTOLOAD) =~ s/.*:://;
        die("'" . $AUTOLOAD . "' : la methode '" . $called . "()' n'existe pas.") unless (exists($self->{$called}));
        return($self->{$called});
    }

    sub DESTROY {
        my $self = shift();
        $self->disconnectFromDB();
        $__sessionsState{'nbSessionsInstanced'}--;
    }
}

1;

#-> END