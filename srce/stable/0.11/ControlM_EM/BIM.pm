#!/usr/bin/perl
#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Module pour consultation du Batch Impact Manager (BIM) ControlEM 6/7/8
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlM EM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 17/03/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE
#   perl -e 'use ControlM_EM::BIM;'
#
# DEPENDANCES OBLIGATOIRES
#   - 'Carp'
#   - 'Exporter'
#   - 'Time::Local'
#   - 'POSIX'
#   - 'DBI'
#   - 'DBD::(Pg|mysql|Oracle|Sybase|ODBC)'
# ATTENTION
#   Ce module se base en partie sur l'heure du systeme qui le charge. Si celle ci est fausse, certains resultats se retrouveront faux.
# AIDE
#   perldoc ControlM_EM::BIM
#==========================================================================================================

#-> BEGIN

#-> POD (Plain Old Documentation)

=pod

=head1 NOM

ControlM_EM::BIM;

=head1 SYNOPSIS

Module pour consultation du Batch Impact Manager (BIM) ControlEM 6/7/8

=head1 DEPENDANCES

Carp, Exporter, Time::Local, POSIX, DBI, /^DBD::(Pg|mysql|Oracle|Sybase|ODBC)$/

=head1 CHARGEMENT

use ControlM_EM::BIM;

=head1 FONCTIONS PUBLIQUES

=over

=item - I<getStatusForService($)>

Cette fonction permet de convertir le champ "status_to" de la hashtable generee par la methode getCurrentServices() (et ses derives) en un status clair et surtout comprehensible ("OK", "Completed OK", "Completed Late", "Warning", "Error").

Renvoie 0 si le parametre fourni n est pas correct.

=item - getNbSessionsInstanced()

Renvoie le nombre d instances de la classe ControlM_EM::BIM en cours.

=item - getNbSessionsConnected()

Renvoie le nombre d instances de la classe ControlM_EM::BIM en cours et connectees a la base du ControM EM.

=back

=head1 METHODES PUBLIQUES

=over

=item - my $session = ControlM_EM::BIM->I<newSession($$$$$$)>

Cette methode est le constructeur de la classe ControlM_EM::BIM.

Pour information, le destructeur DESTROY() est appele lorsque toutes les references a l objet instancie ont ete detruites ("undef($session);" par exemple).

=item - $session->connectToDB()

Cette methode permet de se connecter a la base du ControlEM avec les parametres fournis au constructeur newSession().

=item - $session->disconnectFromDB()

Cette methode permet de se deconnecter de la base du ControlEM mais elle n apelle pas le destructeur DESTROY().

=item - $session->getCurrentServices()

Cette methode retourne une reference de la hashtable de la liste des services en cours dans le Batch Impact Manager (BIM).

Un filtre est disponible avec le parametre "matching" (SQL LIKE clause).

Le parametre "forLastNetName" est un booleen. Si il est vrai alors cette methode ne retournera que les services avec la derniere ODATE. Faux par defaut.

Le parametre "handleDeletedJobs" est un booleen. Si il est vrai alors cette methode ne retournera que les services qui n'ont pas ete supprimes du plan. Vrai par defaut.

La cle de cette hashtable est "log_id".

=item - $session->countCurrentServices()

Cette methode retourne le nombre de services actuellement en cours dans le Batch Impact Manager (BIM).

Cette methode derive de la methode $session->getCurrentServices(), elle herite donc de ses parametres.

=item - $session->workOnCurrentServices()

Cette methode fonctionne de la meme maniere que getCurrentServices() mais elle est surtout le constructeur de la classe __BIMServices qui met a disposition les methodes getProblematicsJobsForServices() et getAlertsForServices().

Cette methode derive de la methode $session->getCurrentServices(), elle herite donc de ses parametres.

=item - $session->getError()

Cette methode retourne la derniere erreur generee (plusieurs erreurs peuvent etre presentes dans la meme chaine de caracteres retournee).

Retourne "undef()" si aucune erreur n est presente ou si la derniere a ete nettoyee via la methode $session->clearError().

Une partie des erreurs sont fatales (notamment le fait de mal utiliser les methodes/fonctions) et celles-ci sont gerees via "Carp::croak()" (plus ou moins equivalent a la fonction built-in "die()").

=item - $session->clearError()

Remplace la valeur de la derniere erreur generee par "undef()".

=item - $session->getSessionIsAlive()

Verifie et retourne l etat (booleen) de la connexion a la base du ControlEM.

Attention, cette methode n est pas fiable pour tous les types de SGBD, voir B<http://search.cpan.org/dist/DBI/DBI.pm#ping>

=item - $session->getSessionIsConnected()

Retourne l etat (booleen) de la connexion a la base du ControlEM.

=back

=head1 PROPRIETES PUBLIQUES (directement et completement manipulables sans accesseurs/modificateurs)

=over

=item - $session->I<{DBMSType}>

Type de SGBD du ControlM EM auquel se connecter.

Les valeurs acceptees sont "Pg", "Oracle", "mysql", "Sybase" et "ODBC". Pour une connexion a MS SQL Server, les drivers "Sybase" et "ODBC" fonctionnent.

=item - $session->I<{DBMSAddress}>

Adresse du SGBD du ControlM EM auquel se connecter.

=item - $session->I<{DBMSPort}>

Port du SGBD du ControlM EM auquel se connecter.

=item - $session->I<{DBMSInstance}>

Instance (ou base) du SGBD du ControlM EM auquel se connecter.

=item - $session->I<{DBMSUser}>

Utilisateur du SGBD du ControlM EM auquel se connecter.

=item - $session->I<{DBMSPassword}>

Mot de passe du SGBD du ControlM EM auquel se connecter.

=item - $session->I<{DBMSTimeout}>

Timeout (en seconde) de la tentavive de connexion au SGBD du ControlM EM.

La valeur 0 signifie qu aucun timeout ne sera applique.

ATTENTION, cette propriete risque de ne pas fonctionner sous Windows (ou d autres systemes ne gerant pas les signaux UNIX).

=back

=head1 EXEMPLES

=over

=item - Afficher la version du module :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM_EM::BIM qw/$VERSION/;

    print($VERSION);

=item - Initialiser une session au Batch Impact Manager (BIM) du ControlM EM, s y connecter et afficher le nombre de services "%ERP%" courants :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM_EM::BIM;

    my $err;

    my $session = ControlM_EM::BIM->newSession(
        "ctmEMVersion" => 7,
        "DBMSType" => "Pg",
        "DBMSAddress" => "127.0.0.1",
        "DBMSPort" => 3306,
        "DBMSInstance" => "controlm_em",
        "DBMSUser" => "root",
        "DBMSPassword" => "root"
    ); # les parametres disponibles sont "ctmEMVersion", "DBMSType", "DBMSAddress", "DBMSPort", "DBMSInstance", "DBMSUser", "DBMSPassword" et "DBMSTimeout"

    $session->connectToDB() || die($session->getError());

    my $nbServices = $sesion->countCurrentServices(
        "matching" => "%ERP%"
    );

    $err = $session->getError();

    defined($err) ? die($err) : print("Il y a " . $nbServices . " *ERP* courants .\n");

=item - Initialiser plusieurs sessions :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM_EM::BIM qw/getNbSessionsInstanced/;

    my %sessionParams = (
        "ctmEMVersion" => 7,
        "DBMSType" => "Pg",
        "DBMSAddress" => "127.0.0.1",
        "DBMSPort" => 3306,
        "DBMSInstance" => "controlm_em",
        "DBMSUser" => "root",
        "DBMSPassword" => "root"
    );

    my $session1 = ControlM_EM::BIM->newSession(%sessionParams);
    my $session2 = ControlM_EM::BIM->newSession(%sessionParams);

    print(getNbSessionsInstanced()) # affiche "2"

=item - Recuperer la liste des noms de service actuellement en cours dans le Batch Impact Manager (BIM) du ControlM EM :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM_EM::BIM;

    my $err;

    my $session = ControlM_EM::BIM->newSession(
        "ctmEMVersion" => 7,
        "DBMSType" => "Pg",
        "DBMSAddress" => "127.0.0.1",
        "DBMSPort" => 3306,
        "DBMSInstance" => "controlm_em",
        "DBMSUser" => "root",
        "DBMSPassword" => "root"
    );

    $session->connectToDB() || die($session->getError());

    my $servicesHashRef = $session->getCurrentServices();

    $err = $session->getError()

    unless (defined($err)) {
        for (values(%{$servicesHashRef}) { # la cle correspond a la propriete "log_id"
            print($_->{service_name} . "\n"); # les proprietes disponibles sont "order_id", "data_center", "service_name", "order_time", "description" et "status_final"
        }
    } else {
        die($err));
    }

=back

=head1 ATTENTION

Ce module se base en partie sur l heure du systeme qui le charge. Si celle ci est fausse, certains resultats se retrouveront faux.

=head1 REMARQUES

=over

=item - Il faudrait se baser sur l heure du ControlM EM pour les calculs si cette donnee est disponible sur sa base de donnees.

=item - Porter le module sous le framework Moose/Moo/Mouse/... (ou plus simplement utiliser le module Tie::SecureHash) serait une solution pour notamment eviter la modification des "attributs privees" critiques (exemple : $session->{__DBI}) de l objet par l utilisateur du module.

=item - La gestion de la version 6 de ControlEM est encore experimentale en version 0.11.

=back

=head1 INFORMATIONS COMPLEMENTAIRES

Module developpe par Yoann Le Garff.

=cut


#----> ** initialisation **

require 5.6.1;

use strict;
use warnings;
use Carp;

#----> ** classes **

{
    #----> ** initialisation **

    package ControlM_EM::BIM;

    use Exporter;
    use Time::Local;
    use POSIX qw/strftime :signal_h/;
    use DBI;

    #----> ** variables de classe **

    our @ISA = qw/Exporter/;
    our @EXPORT_OK = qw/$VERSION getStatusForService getNbSessionsInstanced getNbSessionsConnected/;
    our $AUTOLOAD;
    our $VERSION = 0.115;

    my %__sessionsState = (
        'nbSessionsInstanced' => 0,
        'nbSessionsConnected' => 0
    );

    #----> ** fonctions publiques **

    sub getStatusForService($) {
        my $bimOutput = shift();
        if (defined($bimOutput) && $bimOutput =~ /^\d+$/) {
            if ($bimOutput == 4) {
                return('OK');
            } elsif ($bimOutput == 8) {
                return('Completed OK');
            } elsif ($bimOutput >= 16 && $bimOutput < 128) {
                return('Error');
            } elsif ($bimOutput >= 128 && $bimOutput < 256) {
                return('Warning');
            } elsif ($bimOutput >= 256) {
                return('Completed Late');
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

    #----> ** fonctions privees **

    my $__myOSisUnix = sub {
        my @unixBasedOperatingSystems = (
            'aix', 'bsdos', 'dgux', 'dynixptx', 'freebsd', 'linux', 'hpux', 'irix', 'openbsd', 'dec_osf', 'svr4', 'sco_sv',
            'svr4', 'unicos', 'unicosmk', 'solaris', 'sunos', 'netbsd', 'sco3', 'ultrix', 'macos', 'rhapsody'
        );
        grep(/^${^O}$/i, @unixBasedOperatingSystems) ? return(1) : return(0);
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
                return(1, 0) unless (@tableInfos);
            } else {
                return(0, 0);
            }
        }
        return(1, 1);
    };

    my $__getDatasCentersInfos = sub {
        my $dbh = shift();
        my $sth = $dbh->prepare(<<SQL);
SELECT d.data_center, d.netname, TO_CHAR(t.dt, 'YYYY/MM/DD HH:MI:SS') AS download_time_to_char, c.ctm_daily_time
FROM comm c, (
    SELECT data_center, MAX(download_time) AS dt
    FROM download
    GROUP by data_center
) t JOIN download d ON d.data_center = t.data_center AND t.dt = d.download_time
WHERE c.data_center = d.data_center
AND c.enabled = '1';
SQL
        if ($sth->execute()) {
            my $str = $sth->fetchall_hashref('data_center');
            for (values(%{$str})) {
                ($_->{'active_net_table_name'} = $_->{'netname'}) =~ s/[^\d]//g;
                $_->{'active_net_table_name'} = 'a' . $_->{'active_net_table_name'} . '_ajob';
            }
            keys(%{$str}) ? return(1, $str) : return(1, 0);
        } else {
            return(0, 0);
        }
    };

    my $__getBIMJobsFromActiveNetTable = sub {
        my ($dbh, $deleteFlag, $activeNetTable) = @_;
        my @orderId;
        my $sqlRequest = <<SQL;
SELECT order_id
FROM $activeNetTable
WHERE appl_type = 'BIM'
SQL
        if ($deleteFlag) {
            $sqlRequest .= "AND delete_flag = '0';";
        } else {
            chomp($sqlRequest);
            $sqlRequest .= ';';
        }
        my $sth = $dbh->prepare($sqlRequest);
        if ($sth->execute()) {
            while (my ($orderId) = $sth->fetchrow_array()) {
                push(@orderId, $orderId);
            }
            return(1, \@orderId);
        } else {
            return(0, 0);
        }
    };

    my $__getAllServices = sub {
        my ($dbh, $matching, $jobsInformations, $datacenterInfos, $forLastNetName) = @_;
        my (%servicesHash, @errorByNetName);
        for (keys(%{$datacenterInfos})) {
            if ($jobsInformations->{$_} && @{$jobsInformations->{$_}}) {
                my $sqlInClause = join(' ', map({"'" . $_ . "'," } @{$jobsInformations->{$_}}));
                chop($sqlInClause);
                my $sqlRequest = <<SQL;
SELECT *, TO_CHAR(order_time, 'YYYY/MM/DD HH:MI:SS') AS order_time_to_char
FROM bim_log
WHERE log_id IN (
    SELECT MAX(log_id)
    FROM bim_log
    GROUP BY order_id
)
AND service_name LIKE '$matching'
AND order_id IN ($sqlInClause)
SQL
                if ($forLastNetName) {
                    $sqlRequest .= <<SQL;

AND active_net_name = '$datacenterInfos->{$_}->{'netname'}'
SQL
                }
                $sqlRequest .= <<SQL;

ORDER BY service_name;
SQL
                my $sth = $dbh->prepare($sqlRequest);
                if ($sth->execute()) {
                    %servicesHash = (%servicesHash, %{$sth->fetchall_hashref('log_id')});
                } else {
                    push(@errorByNetName, $datacenterInfos->{$_}->{'netname'});
                }
            }
        }
        return(\@errorByNetName, \%servicesHash);
    };

    my $__calculStartEndDayTimeInPosixTimestamp = sub {
        my ($time, $ctmDailyTime, $previousNextOrAll) = @_;
        if ($ctmDailyTime =~ /^[\+\-]\d{4}$/) {
            #-> a mod pour +/- (0.12) et la prise en compte de CTM 6.x (0.20)
            my ($ctmDailyPreviousOrNext, $ctmDailyHour, $ctmDailyMin) = (substr($ctmDailyTime, 0, 1), unpack('(a2)*', substr($ctmDailyTime, 1, 4)));
            my ($minNow, $hoursNow, $dayNow, $monthNow, $yearNow) = split(/\s+/, strftime('%M %H %d %m %Y', localtime($time)));
            my ($previousDay, $previousDayMonth, $previousDayYear) = split(/\s+/, strftime('%d %m %Y', localtime($time - 86400)));
            my ($nextDay, $nextDayMonth, $nextDayYear) = split(/\s+/, strftime('%d %m %Y', localtime($time + 86400)));
            my ($startDayTimeInPosixTimestamp, $endDayTimeInPosixTimestamp);
            if ($hoursNow >= $ctmDailyHour && $minNow >= $ctmDailyMin) {
                $startDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($yearNow . '/' . $monthNow . '/' . $dayNow . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
                $endDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($nextDayYear . '/' . $nextDayMonth . '/' . $nextDay . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
            } else {
                $startDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($previousDayYear . '/' . $previousDayMonth . '/' . $previousDay . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
                $endDayTimeInPosixTimestamp = $__dateToPosixTimestamp->($yearNow . '/' . $monthNow . '/' . $dayNow . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
            }
            #-< a mod pour +/- (0.12) et la prise en compte de CTM 6.x (0.20)
            for ($previousNextOrAll) {
                /^\*$/ && return(1, $startDayTimeInPosixTimestamp, $endDayTimeInPosixTimestamp);
                /^\+$/ && return(1, $endDayTimeInPosixTimestamp);
                return(1, $startDayTimeInPosixTimestamp);
            }
        }
        return(0, 0);
    };

    #----> ** methodes publiques **

    #-> constructeur

    sub newSession {
        my ($class, %params) = (shift(), @_);
        $class = ref($class) || $class;
        my $self = {};
        $__sessionsState{'nbSessionsInstanced'}++;
        $self->{'__errorMessage'} = undef();
        $self->{'__sessionIsConnected'} = 0;
        if (exists($params{'ctmEMVersion'}) && exists($params{'DBMSType'}) && exists($params{'DBMSAddress'}) && exists($params{'DBMSPort'}) && exists($params{'DBMSInstance'}) && exists($params{'DBMSUser'})) {
            $self->{'__ctmEMVersion'} = $params{'ctmEMVersion'};
            $self->{'DBMSType'} = $params{'DBMSType'};
            $self->{'DBMSAddress'} = $params{'DBMSAddress'};
            $self->{'DBMSPort'} = $params{'DBMSPort'};
            $self->{'DBMSInstance'} = $params{'DBMSInstance'};
            $self->{'DBMSUser'} = $params{'DBMSUser'};
            $self->{'DBMSPassword'} = exists($params{'DBMSPassword'}) ? $params{'DBMSPassword'} : undef();
            $self->{'DBMSTimeout'} = (exists($params{'DBMSTimeout'}) && defined($params{'DBMSTimeout'}) && $params{'DBMSTimeout'} >= 0) ? $params{'DBMSTimeout'} : 0;
            # [root@shl90255 ControlM_EM_BIM_module]# ./check_test.pl -s test -w OK=1 -c OK=2 -h shl90062 -b pcme01nt
            # Use of uninitialized value $params{"DBMSTimeout"} in numeric ge (>=) at /usr/local/lib64/perl5/ControlM_EM/BIM.pm line 526.
            # UNKNOWN - 'DBI' : 'could not connect to server: Connexion refusÃÂ©e Is the server running on host "shl90062" and accepting TCP/IP connections on port 330
        } else {
            Carp::croak("'newSession()' : un ou plusieurs parametres obligatoires ne sont pas declares.");
        }
        return(bless($self, $class));
    }

    #-> connect/disconnect

    sub connectToDB {
        my $self = shift();
        $self->clearError();
        if (exists($self->{'__ctmEMVersion'}) && exists($self->{'DBMSType'}) && exists($self->{'DBMSAddress'}) && exists($self->{'DBMSPort'}) && exists($self->{'DBMSInstance'}) && exists($self->{'DBMSUser'})) {
            if ($self->{'__ctmEMVersion'} =~ /^[678]$/ && $self->{'DBMSType'} =~ /^(Pg|Oracle|mysql|Sybase|ODBC)$/ && $self->{'DBMSAddress'} ne '' && $self->{'DBMSPort'} =~ /^\d+$/ && $self->{'DBMSPort'} >= 0  && $self->{'DBMSPort'} <= 65535 && $self->{'DBMSInstance'} ne '' && $self->{'DBMSUser'} ne '') {
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
                        $self->clearError();
                        eval {
                            my $connectionString = 'dbi:' . $self->{'DBMSType'};
                            if ($self->{'DBMSType'} eq 'ODBC') {
                                $connectionString .= ':driver={SQL Server};server=' . $self->{'DBMSAddress'} . ',' . $self->{'DBMSPort'} . ';database=' . $self->{'DBMSInstance'};
                            } else {
                                $connectionString .= ':host=' . $self->{'DBMSAddress'} . ';database=' . $self->{'DBMSInstance'} . ';port=' . $self->{'DBMSPort'};
                            }
                            $self->{'__DBI'} = DBI->connect(
                                $connectionString,
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
                        my ($situation, $testTables) = $__doesTablesExists->($self->{'__DBI'}, 'bim_log', 'bim_prob_jobs', 'bim_alert', 'comm', 'download');
                        if ($situation) {
                            if ($testTables) {
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
                Carp::croak("'connectToDB()' : un ou plusieurs parametres ne sont pas valides.");
            }
        } else {
            Carp::croak("'connectToDB()' : un ou plusieurs parametres ne sont pas valides.");
        }
        return(0);
    }

    sub disconnectFromDB {
        my $self = shift();
        $self->clearError();
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

    #-> methodes liees aux services

    sub getCurrentServices {
        my ($self, %params) = (shift(), @_);
        $params{'matching'} = '%' unless (exists($params{'matching'}));
        $params{'forLastNetName'} = 0 unless (exists($params{'forLastNetName'}));
        $params{'handleDeletedJobs'} = 1 unless (exists($params{'handleDeletedJobs'}));
        $self->clearError();
        my ($situation, $datacenterInfos);
        if ($self->getSessionIsConnected()) {
            ($situation, $datacenterInfos) = $__getDatasCentersInfos->($self->{'__DBI'});
            if ($situation) {
                my $time = time();
                my %jobsInformations = map({$_, undef()} keys(%{$datacenterInfos}));
                my @activeNetTablesInError;
                for my $dataCenter (keys(%{$datacenterInfos})) {
                    ($situation, my $datacenterOdateStart, my $datacenterOdateEnd) = $__calculStartEndDayTimeInPosixTimestamp->($time, $datacenterInfos->{$dataCenter}->{'ctm_daily_time'}, '*');
                    if ($situation) {
                        my $downloadTimeInTimestamp;
                        eval {
                            $downloadTimeInTimestamp = $__dateToPosixTimestamp->($datacenterInfos->{$dataCenter}->{'download_time_to_char'});
                        };
                        unless ($downloadTimeInTimestamp == 0 || $@) {
                            if ($downloadTimeInTimestamp >= $datacenterOdateStart && $downloadTimeInTimestamp <= $datacenterOdateEnd) {
                                ($situation, $jobsInformations{$dataCenter}) = $__getBIMJobsFromActiveNetTable->($self->{'__DBI'}, $params{'handleDeletedJobs'}, $datacenterInfos->{$dataCenter}->{'active_net_table_name'});
                                push(@activeNetTablesInError, $datacenterInfos->{$dataCenter}->{'active_net_table_name'}) unless ($situation);
                            } else {
                                delete($jobsInformations{$dataCenter});
                            }
                        } else {
                            $self->{'__errorMessage'} .= ($self->{'__errorMessage'} && ' ') . "'getCurrentServices()' : le champ 'download_time_to_char' qui derive de la cle 'download_time' (DATETIME) via la fonction SQL TO_CHAR() (Control-M '" . $datacenterInfos->{$dataCenter}->{'service_name'} . "') n'est pas correct ou n'est pas gere par le module. Il est possible que la base de donnees du ControlEM soit corrompue ou que la version renseignee (version '" . $self->{'__ctmEMVersion'} . "') ne soit pas correcte.";
                            return(0);
                        }
                    } else {
                        $self->{'__errorMessage'} .= ($self->{'__errorMessage'} && ' ') . "'getCurrentServices()' : le champ 'ctm_daily_time' du datacenter '" . $datacenterInfos->{$dataCenter}->{'data_center'} . "' n'est pas correct " . '(=~ /^[\+\-]\d{4}$/).';
                        return(0);
                    }
                }
                $self->{'__errorMessage'} = "'getCurrentServices()' : erreur lors des jobs BIM : la methode DBI 'execute()' a echoue pour une ou plusieurs tables de l'active net : '" . join(' ', @activeNetTablesInError) . "'." if (@activeNetTablesInError);
                ($situation, my $servicesDatas) = $__getAllServices->($self->{'__DBI'}, $params{'matching'}, \%jobsInformations, $datacenterInfos, $params{'forLastNetName'});
                $self->{'__errorMessage'} .= ($self->{'__errorMessage'} && ' ') . "'getCurrentServices()' : la methode DBI 'execute()' a echoue pour les netnames suivants : '" . join(' ', @{$situation}) . "'." if (@{$situation});
                return($servicesDatas);
            } else {
                $self->{'__errorMessage'} = "'getCurrentServices()' : erreur lors de la recuperation des informations a propos des ControlM Server : la methode DBI 'execute()' a echoue : '" . $self->{'__DBI'}->errstr() . "'.";
            }
        } else {
             $self->{'__errorMessage'} = "'getCurrentServices()' : impossible de continuer car la connexion au SGBD n'est pas active.";
        }
        return(0);
    }

    sub countCurrentServices {
        my ($self, %params) = (shift(), @_);
        $params{'matching'} = '%' unless (exists($params{'matching'}));
        $params{'forLastNetName'} = 0 unless (exists($params{'forLastNetName'}));
        $params{'handleDeletedJobs'} = 1 unless (exists($params{'handleDeletedJobs'}));
        my $getCurrentServices = $self->getCurrentServices(
            'matching' => $params{'matching'},
            'forLastNetName' => $params{'forLastNetName'},
            'handleDeletedJobs' => $params{'handleDeletedJobs'}
        );
        (ref($getCurrentServices) eq 'HASH') ? return(scalar(keys(%{$getCurrentServices}))) : return($getCurrentServices);
    }

    sub workOnCurrentServices {
        my ($self, %params) = (shift(), @_);
        $params{'matching'} = '%' unless (exists($params{'matching'}));
        $params{'forLastNetName'} = 0 unless (exists($params{'forLastNetName'}));
        $params{'handleDeletedJobs'} = 1 unless (exists($params{'handleDeletedJobs'}));
        my $subSelf = {};
        $self->clearError();
        $subSelf->{'__ControlM_EM::BIM'} = $self;
        $subSelf->{'__currentServices'} = $self->getCurrentServices(
            'matching' => $params{'matching'},
            'forLastNetName' => $params{'forLastNetName'},
            'handleDeletedJobs' => $params{'handleDeletedJobs'}
        );
        return(bless($subSelf, '__BIMServices'));
    }

    #-> accesseurs/mutateurs

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
            $self->{'__errorMessage'} = "'getSessionIsAlive()' : impossible de tester l'etat de la connexion au SGBD car celle ci n'est pas active.";
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
        no strict qw/refs/;
        (my $called = $AUTOLOAD) =~ s/.*:://;
        Carp::croak("'" . $AUTOLOAD . "' : la methode '" . $called . "()' n'existe pas.") unless (exists($self->{$called}));
        return($self->{$called});
    }

    sub DESTROY {
        my $self = shift();
        $self->disconnectFromDB();
        $__sessionsState{'nbSessionsInstanced'}--;
    }
}

#-> ** classe du constructeur ControlM_EM::BIM::workOnCurrentServices() **

{
    #----> ** initialisation **

    package __BIMServices;

    #----> ** variables de classe **

    our $AUTOLOAD;

    #----> ** fonctions privees **

    my $__getAllViaLogID = sub {
        my ($dbh, $sqlRequest, @servicesLogID) = @_;
        my $sqlInClause = join(' ', map({"'" . $_ . "'," } @servicesLogID));
        chop($sqlInClause);
        $sqlRequest .= ' WHERE log_id IN (' . $sqlInClause . ');';
        my $sth = $dbh->prepare($sqlRequest);
        if ($sth->execute()) {
            return(1, $sth->fetchall_hashref('log_id'));
        } else {
            return(0, 0);
        }
    };

    #----> ** methodes publiques **

    #-> methodes liees aux services

    sub getAlertsForServices {
        my $self = shift();
        if ($self->{'__ControlM_EM::BIM'}->getSessionIsConnected()) {
            if ($self->{'__currentServices'}) {
                my @servicesLogID = keys(%{$self->{'__currentServices'}});
                if (@servicesLogID) {
                    my ($situation, $hashRefPAlertsJobsForServices) = $__getAllViaLogID->($self->{'__ControlM_EM::BIM'}->{'__DBI'}, 'SELECT * FROM bim_alert', @servicesLogID);
                    if ($situation) {
                        return($hashRefPAlertsJobsForServices);
                    } else {
                        $self->{'__errorMessage'} = "'getAlertsForServices()' : erreur lors de la recuperation de la liste des jobs : la methode DBI 'execute()' a echouee : '" . $self->{'__ControlM_EM::BIM;'}->{'__DBI'}->errstr() . "'.";
                    }
                } else {
                    return({});
                }
            } else {
                $self->{'__errorMessage'} = "'getAlertsForServices()' : impossible de recuperer les alertes, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."
            }
        } else {
            $self->{'__errorMessage'} = "'getAlertsForServices()' : impossible de continuer car la connexion au SGBD n'est pas active.";
        }
        return(0);
    }

    sub getProblematicsJobsForServices {
        my $self = shift();
        if ($self->{'__ControlM_EM::BIM'}->getSessionIsConnected()) {
            if ($self->{'__currentServices'}) {
                my @servicesLogID = keys(%{$self->{'__currentServices'}});
                if (@servicesLogID) {
                    my ($situation, $hashRefProblematicsJobsForServices) = $__getAllViaLogID->($self->{'__ControlM_EM::BIM'}->{'__DBI'}, 'SELECT * FROM bim_prob_jobs', @servicesLogID);
                    if ($situation) {
                        return($hashRefProblematicsJobsForServices);
                    } else {
                        $self->{'__errorMessage'} = "'getProblematicsJobsForServices()' : erreur lors de la recuperation de la liste des jobs : la methode DBI 'execute()' a echouee : '" . $self->{'__ControlM_EM::BIM;'}->{'__DBI'}->errstr() . "'.";
                    }
                } else {
                    return({});
                }
            } else {
                $self->{'__errorMessage'} = "'getProblematicsJobsForServices()' : impossible de recuperer les jobs en erreur, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."
            }
        } else {
            $self->{'__errorMessage'} = "'getProblematicsJobsForServices()' : impossible de continuer car la connexion au SGBD n'est pas active.";
        }
        return(0);
    }

    #-> accesseurs/mutateurs

    sub getError {
        my $self = shift();
        return($self->{'__errorMessage'});
    }

    sub clearError {
        my $self = shift();
        $self->{'__errorMessage'} = undef();
    }

    #-> Perl BuiltIn

    sub AUTOLOAD {
        my $self = shift();
        no strict qw/refs/;
        (my $called = $AUTOLOAD) =~ s/.*:://;
        Carp::croak("'" . $AUTOLOAD . "' : la methode '" . $called . "()' n'existe pas.") unless (exists($self->{$called}));
        return($self->{$called});
    }
}

1;

#-> END