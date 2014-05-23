#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Module pour consultation des services du Batch Impact Manager (BIM) ControlMEM v6/7/8
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlMEM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 17/03/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE / AIDE
#   perldoc ControlM::EM::BIM::ServicesAPI
#
# DEPENDANCES OBLIGATOIRES
#   - 'ControlM::EM::BIM::ServicesAPI::Common'
#   - 'Carp'
#   - 'Hash::Util'
#   - 'Exporter'
#   - 'Time::Local'
#   - 'POSIX'
#   - 'DBI'
#   - 'DBD::(Pg|mysql|Oracle|Sybase|ODBC)'
#==========================================================================================================

#-> BEGIN

#----> ** initialisation **

require 5.6.1;

use strict;
use warnings;

use Carp;
use Hash::Util;
use ControlM::EM::BIM::ServicesAPI::Common 0.14;

#----> ** classes **

{
    #----> ** initialisation **

    package ControlM::EM::BIM::ServicesAPI;

    use base qw/ControlM::EM::BIM::ServicesAPI::Common Exporter/;

    use Exporter;
    use Time::Local;
    use POSIX qw/strftime :signal_h/;
    use DBI;

    #----> ** variables de classe **

    our $VERSION = 0.14;
    our $AUTOLOAD;
    our @EXPORT_OK = qw/
        $VERSION
        getStatusColorForService
        getNbSessionsCreated
        getNbSessionsConnected
    /;

    my %_sessionsState = (
        'nbSessionsInstanced' => 0,
        'nbSessionsConnected' => 0
    );

    #----> ** fonctions publiques **

    sub getStatusColorForService($) {
        my $statusTo = shift;
        $statusTo = $statusTo->{'status_to'} if (ref $statusTo eq 'HASH');
        if (defined $statusTo && $statusTo =~ /^\d+$/) {
            if ($statusTo == 4) {
                return 'OK';
            } elsif ($statusTo == 8) {
                return 'Completed OK';
            } elsif ($statusTo >= 16 && $statusTo < 128) {
                return 'Error';
            } elsif ($statusTo >= 128 && $statusTo < 256) {
                return 'Warning';
            } elsif ($statusTo >= 256) {
                return 'Completed Late';
            }
        }
        return 0;
    }

    sub getNbSessionsCreated {
        return $_sessionsState{'nbSessionsInstanced'};
    }

    sub getNbSessionsConnected {
        return $_sessionsState{'nbSessionsConnected'};
    }

    #----> ** fonctions privees **

    my $_myOSIsUnix = sub {
        return grep (/^${^O}$/i, qw/aix bsdos dgux dynixptx freebsd linux hpux irix openbsd dec_osf svr4 sco_sv svr4 unicos unicosmk solaris sunos netbsd sco3 ultrix macos rhapsody/);
    };

    my $_doesTablesExists = sub {
        my ($dbh, @tablesName) = @_;
        my @inexistingSQLTables;
        for (@tablesName) {
            my $sth = $dbh->table_info(undef, 'public', $_, 'TABLE');
            if ($sth->execute()) {
                push @inexistingSQLTables, $_ unless ($sth->fetchrow_array());
            } else {
                return 0, 0;
            }
        }
        return 1, \@inexistingSQLTables;
    };

    my $_getDatasCentersInfos = sub {
        my ($dbh, $verbose) = @_;
        my $sqlRequest = <<SQL;
SELECT d.data_center, d.netname, TO_CHAR(t.dt, 'YYYY/MM/DD HH:MI:SS') AS download_time_to_char, c.ctm_daily_time
FROM comm c, (
    SELECT data_center, MAX(download_time) AS dt
    FROM download
    GROUP by data_center
) t JOIN download d ON d.data_center = t.data_center AND t.dt = d.download_time
WHERE c.data_center = d.data_center
AND c.enabled = '1';
SQL
        print "> VERBOSE - \$_getDatasCentersInfos->() :\n\n" . $sqlRequest . "\n" if ($verbose);
        my $sth = $dbh->prepare($sqlRequest);
        if ($sth->execute()) {
            my $str = $sth->fetchall_hashref('data_center');
            for (values %{$str}) {
                ($_->{'active_net_table_name'} = $_->{'netname'}) =~ s/[^\d]//g;
                $_->{'active_net_table_name'} = 'a' . $_->{'active_net_table_name'} . '_ajob';
            }
            keys %{$str} ? return 1, $str : return 1, 0;
        } else {
            return 0, 0;
        }
    };

    my $_getBIMJobsFromActiveNetTable = sub {
        my ($dbh, $deleteFlag, $activeNetTable, $verbose) = @_;
        my @orderId;
        my $sqlRequest = <<SQL;
SELECT order_id
FROM $activeNetTable
WHERE appl_type = 'BIM'
SQL
        if ($deleteFlag) {
            $sqlRequest .= "AND delete_flag = '0';";
        } else {
            chomp $sqlRequest;
            $sqlRequest .= ';';
        }
        print "> VERBOSE - \$_getBIMJobsFromActiveNetTable->() :\n\n" . $sqlRequest . "\n" if ($verbose);
        my $sth = $dbh->prepare($sqlRequest);
        if ($sth->execute()) {
            while (my ($orderId) = $sth->fetchrow_array()) {
                push @orderId, $orderId;
            }
            return 1, \@orderId;
        } else {
            return 0, 0;
        }
    };

    my $_getAllServices = sub {
        my ($dbh, $matching, $jobsInformations, $datacenterInfos, $forLastNetName, $verbose) = @_;
        my (%servicesHash, @errorByNetName);
        for (keys(%{$datacenterInfos})) {
            if ($jobsInformations->{$_} && @{$jobsInformations->{$_}}) {
                my $sqlInClause = join "', '", @{$jobsInformations->{$_}};
                my $sqlRequest = <<SQL;
SELECT *, TO_CHAR(order_time, 'YYYY/MM/DD HH:MI:SS') AS order_time_to_char
FROM bim_log
WHERE log_id IN (
    SELECT MAX(log_id)
    FROM bim_log
    GROUP BY order_id
)
AND service_name LIKE '$matching'
AND order_id IN ('$sqlInClause')
SQL
                if ($forLastNetName) {
                    $sqlRequest .= <<SQL;

AND active_net_name = '$datacenterInfos->{$_}->{'netname'}'
SQL
                }
                $sqlRequest .= <<SQL;
ORDER BY service_name;
SQL
                print "> VERBOSE - \$_getAllServices->() :\n\n" . $sqlRequest . "\n" if ($verbose);
                my $sth = $dbh->prepare($sqlRequest);
                if ($sth->execute()) {
                    %servicesHash = (%servicesHash, %{$sth->fetchall_hashref('log_id')});
                } else {
                    push @errorByNetName, $datacenterInfos->{$_}->{'netname'};
                }
            }
        }
        return \@errorByNetName, \%servicesHash;
    };

    my $_dateToPosixTimestamp = sub {
        my ($year, $mon, $day, $hour, $min, $sec) = split /[\/\-\s:]+/, shift;
        my $time = timelocal($sec, $min, $hour, $day, $mon - 1 ,$year);
        return $time =~ /^\d+$/ ? $time : undef;
    };

    my $_calculStartEndDayTimeInPosixTimestamp = sub {
        my ($time, $ctmDailyTime, $previousNextOrAll) = @_;
        if ($ctmDailyTime =~ /^[\+\-]\d{4}$/) {
            #-> a mod pour +/- (0.12) et la prise en compte de CTM 6.x (0.20)
            my ($ctmDailyPreviousOrNext, $ctmDailyHour, $ctmDailyMin) = (substr($ctmDailyTime, 0, 1), unpack '(a2)*', substr $ctmDailyTime, 1, 4);
            my ($minNow, $hoursNow, $dayNow, $monthNow, $yearNow) = split /\s+/, strftime('%M %H %d %m %Y', localtime $time);
            my ($previousDay, $previousDayMonth, $previousDayYear) = split /\s+/, strftime('%d %m %Y', localtime $time - 86400);
            my ($nextDay, $nextDayMonth, $nextDayYear) = split /\s+/, strftime('%d %m %Y', localtime $time + 86400);
            my ($startDayTimeInPosixTimestamp, $endDayTimeInPosixTimestamp);
            if ($hoursNow >= $ctmDailyHour && $minNow >= $ctmDailyMin) {
                $startDayTimeInPosixTimestamp = $_dateToPosixTimestamp->($yearNow . '/' . $monthNow . '/' . $dayNow . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
                $endDayTimeInPosixTimestamp = $_dateToPosixTimestamp->($nextDayYear . '/' . $nextDayMonth . '/' . $nextDay . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
            } else {
                $startDayTimeInPosixTimestamp = $_dateToPosixTimestamp->($previousDayYear . '/' . $previousDayMonth . '/' . $previousDay . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
                $endDayTimeInPosixTimestamp = $_dateToPosixTimestamp->($yearNow . '/' . $monthNow . '/' . $dayNow . '-' . $ctmDailyHour . ':' . $ctmDailyMin . ':' . 00);
            }
            #-< a mod pour +/- (0.12) et la prise en compte de CTM 6.x (0.20)
            if (defined $startDayTimeInPosixTimestamp && defined $endDayTimeInPosixTimestamp) {
                for ($previousNextOrAll) {
                    /^\*$/ && return 1, $startDayTimeInPosixTimestamp, $endDayTimeInPosixTimestamp;
                    /^\+$/ && return 1, $endDayTimeInPosixTimestamp;
                    return 1, $startDayTimeInPosixTimestamp;
                }
            } else {
                return 0, 1;
            }
        }
        return 0, 0;
    };

    my $_myErrorMessage = sub {
        my ($nameSpace, $message) = @_;
        return "'" . $nameSpace . "()' : " . $message;
    };

    #-> ** methodes privees **

    #-> accesseurs/mutateurs

    my $_setObjProperty = sub {
        my ($self, $property, $value) = @_;
        Hash::Util::unlock_value(%{$self}, $property);
        $self->{$property} = $value;
        Hash::Util::lock_value(%{$self}, $property);
        return 1;
    };

    #-> constructeurs (methode privee)

    my $_servicesAPIConstructor = sub {
        Carp::croak($_myErrorMessage->((caller 0)[3], "la methode n'est pas correctement declaree.")) unless (@_ % 2);
        my ($class, %params) = (shift, @_);
        my $self = {};
        if (exists $params{'ctmEMVersion'} && exists $params{'DBMSType'} && exists $params{'DBMSAddress'} && exists $params{'DBMSPort'} && exists $params{'DBMSInstance'} && exists $params{'DBMSUser'}) {
            $self->{'_ctmEMVersion'} = $params{'ctmEMVersion'};
            $self->{'DBMSType'} = $params{'DBMSType'};
            $self->{'DBMSAddress'} = $params{'DBMSAddress'};
            $self->{'DBMSPort'} = $params{'DBMSPort'};
            $self->{'DBMSInstance'} = $params{'DBMSInstance'};
            $self->{'DBMSUser'} = $params{'DBMSUser'};
            $self->{'DBMSPassword'} = exists $params{'DBMSPassword'} ? $params{'DBMSPassword'} : undef;
            $self->{'DBMSTimeout'} = (exists $params{'DBMSTimeout'} && defined $params{'DBMSTimeout'} && $params{'DBMSTimeout'} >= 0) ? $params{'DBMSTimeout'} : 0;
            $self->{'verbose'} = (exists $params{'verbose'} && defined $params{'verbose'}) ? $params{'verbose'} : 0;
        } else {
            Carp::croak($_myErrorMessage->((caller 0)[3], "la methode n'est pas correctement declaree."));
        }
        $self->{'_errorMessage'} = undef;
        $self->{'_DBI'} = undef;
        $self->{'_sessionIsConnected'} = 0;
        $class = ref $class || $class;
        $_sessionsState{'nbSessionsInstanced'}++;
        return bless $self, $class;
    };

    my $_WorkOnServicesConstructor = sub {
        Carp::croak($_myErrorMessage->((caller 0)[3], "la methode n'est pas correctement declaree.")) unless (@_ % 2);
        my ($self, %params) = (shift, @_);
        my $subSelf = {};
        $self->clearError();
        $subSelf->{'_ControlM::EM::BIM::ServicesAPI'} = $self;
        $subSelf->{'_errorMessage'} = undef;
        $subSelf->{'_working'} = 0;
        $subSelf->{'_currentServices'} = $self->getCurrentServices(
            'matching' => exists $params{'matching'} ? $params{'matching'} : '%',
            'forLastNetName' => exists $params{'forLastNetName'} ? $params{'forLastNetName'} : 0,
            'handleDeletedJobs' => exists $params{'handleDeletedJobs'} ? $params{'handleDeletedJobs'} : 1
        );
        return bless $subSelf, '_WorkOnServices';
    };

    #-> connect/disconnect

    my $_connectToDB = sub {
        my $self = shift;
        $self->clearError();
        if (exists $self->{'_ctmEMVersion'} && exists $self->{'DBMSType'} && exists $self->{'DBMSAddress'} && exists $self->{'DBMSPort'} && exists $self->{'DBMSInstance'} && exists $self->{'DBMSUser'}) {
            if ($self->{'_ctmEMVersion'} =~ /^[678]$/ && $self->{'DBMSType'} =~ /^(Pg|Oracle|mysql|Sybase|ODBC)$/ && $self->{'DBMSAddress'} ne '' && $self->{'DBMSPort'} =~ /^\d+$/ && $self->{'DBMSPort'} >= 0  && $self->{'DBMSPort'} <= 65535 && $self->{'DBMSInstance'} ne '' && $self->{'DBMSUser'} ne '') {
                unless ($self->getSessionIsConnected()) {
                    if (eval 'require DBD::' . $self->{'DBMSType'}) {
                        my $myOSIsUnix = $_myOSIsUnix->();
                        my $ALRMDieSub = sub {
                            die "'DBI' : impossible de se connecter (timeout atteint) a la base '" . $self->{'DBMSType'} . ", instance '" .  $self->{'DBMSInstance'} . "' du serveur '" .  $self->{'DBMSType'} . "'.";
                        };
                        my $oldaction;
                        if ($myOSIsUnix) {
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
                            $self->{'_DBI'} = DBI->connect(
                                $connectionString,
                                $self->{'DBMSUser'},
                                $self->{'DBMSPassword'},
                                {
                                    'RaiseError' => 0,
                                    'PrintError' => 0,
                                    'AutoCommit' => 1
                                }
                            ) || do {
                                (my $errorMessage = "'DBI' : '" . $DBI::errstr . "'.") =~ s/\s+/ /g;
                                $_setObjProperty->($self, '_errorMessage', $errorMessage);
                            };
                        };
                        alarm 0;
                        sigaction(SIGALRM, $oldaction) if ($myOSIsUnix);
                        return 0 if ($self->{'_errorMessage'});
                        if ($@) {
                            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], $@));
                            return 0;
                        }
                        my ($situation, $inexistingSQLTables) = $_doesTablesExists->($self->{'_DBI'}, qw/bim_log bim_prob_jobs bim_alert comm download/);
                        if ($situation) {
                            unless (@{$inexistingSQLTables}) {
                                $_setObjProperty->($self, '_sessionIsConnected', 1);
                                $_sessionsState{'nbSessionsConnected'}++;
                                return 1;
                            } else {
                                $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "la connexion au SGBD est etablie mais il manque une ou plusieurs tables ('" . join("', '", @{$inexistingSQLTables}) . "') qui sont requises ."));
                            }
                        } else {
                            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "la connexion est etablie mais la ou les methodes DBI 'table_info()'/'execute()' ont echouees."));
                        }
                    } else {
                        $@ =~ s/\s+/ /g;
                        $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de charger le module 'DBD::" . $self->{'DBMSType'} . "' : '" . $@ . "'."));
                    }
                } else {
                    $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de se connecter car cette instance est deja connectee."));
                }
            } else {
                Carp::croak($_myErrorMessage->((caller 0)[3], "un ou plusieurs parametres ne sont pas valides."));
            }
        } else {
            Carp::croak($_myErrorMessage->((caller 0)[3], "un ou plusieurs parametres ne sont pas valides."));
        }
        return 0;
    };

    my $_disconnectFromDB = sub {
        my $self = shift;
        $self->clearError();
        if ($self->{'_sessionIsConnected'}) {
            if ($self->{'_DBI'}->disconnect()) {
                $_setObjProperty->($self, '_sessionIsConnected', 0);
                $_sessionsState{'nbSessionsConnected'}--;
                return 1;
            } else {
                $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], 'DBI : ' . $self->{'_DBI'}->errstr()));
            }
        } else {
            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de clore la connexion car cette instance n'est pas connectee."));
        }
        return 0;
    };

    #----> ** methodes publiques **

    #-> alias de methodes privees

    sub newSession {
        my $self = shift->$_servicesAPIConstructor(@_);
        Hash::Util::lock_hash(%{$self});
        return $self;
    }

    *new = \&newSession;

    sub connectToDB {
        my $self = shift;
        Hash::Util::unlock_value(%{$self}, '_DBI');
        my $return = $self->$_connectToDB(@_);
        Hash::Util::lock_value(%{$self}, '_DBI');
        return $return;
    }

    sub disconnectFromDB {
        my $self = shift;
        Hash::Util::unlock_value(%{$self}, '_DBI');
        my $return = $self->$_disconnectFromDB(@_);
        Hash::Util::lock_value(%{$self}, '_DBI');
        return $return;
    }

    #-> methodes liees aux services

    sub getCurrentServices {
        Carp::croak($_myErrorMessage->((caller 0)[3], "la methode n'est pas correctement declaree.")) unless (@_ % 2);
        my ($self, %params) = (shift, @_);
        $self->clearError();
        my ($situation, $datacenterInfos);
        if ($self->getSessionIsConnected()) {
            ($situation, $datacenterInfos) = $_getDatasCentersInfos->($self->{'_DBI'}, $self->{'verbose'});
            if ($situation) {
                my $time = time;
                my %jobsInformations = map { $_, undef } keys %{$datacenterInfos};
                my @activeNetTablesInError;
                for my $dataCenter (keys %{$datacenterInfos}) {
                    ($situation, my $datacenterOdateStart, my $datacenterOdateEnd) = $_calculStartEndDayTimeInPosixTimestamp->($time, $datacenterInfos->{$dataCenter}->{'ctm_daily_time'}, '*');
                    if ($situation) {
                        my $downloadTimeInTimestamp;
                        eval {
                            $downloadTimeInTimestamp = $_dateToPosixTimestamp->($datacenterInfos->{$dataCenter}->{'download_time_to_char'});
                        };
                        unless ($downloadTimeInTimestamp == 0 || $@) {
                            if ($downloadTimeInTimestamp >= $datacenterOdateStart && $downloadTimeInTimestamp <= $datacenterOdateEnd) {
                                ($situation, $jobsInformations{$dataCenter}) = $_getBIMJobsFromActiveNetTable->($self->{'_DBI'}, exists $params{'handleDeletedJobs'} ? $params{'handleDeletedJobs'} : 1, $datacenterInfos->{$dataCenter}->{'active_net_table_name'}, $self->{'verbose'});
                                push @activeNetTablesInError, $datacenterInfos->{$dataCenter}->{'active_net_table_name'} unless ($situation);
                            } else {
                                delete $jobsInformations{$dataCenter};
                            }
                        } else {
                            $_setObjProperty->($self, '_errorMessage', ($self->{'_errorMessage'} && $self->{'_errorMessage'} . ' ') . $_myErrorMessage->((caller 0)[3], "le champ 'download_time_to_char' qui derive de la cle 'download_time' (DATETIME) via la fonction SQL TO_CHAR() (Control-M '" . $datacenterInfos->{$dataCenter}->{'service_name'} . "') n'est pas correct ou n'est pas gere par le module. Il est possible que la base de donnees du ControlMEM soit corrompue ou que la version renseignee (version '" . $self->{'_ctmEMVersion'} . "') ne soit pas correcte."));
                            return 0;
                        }
                    } else {
                        if ($datacenterOdateStart) {
                            $_setObjProperty->($self, '_errorMessage', ($self->{'_errorMessage'} && $self->{'_errorMessage'} . ' ') . $_myErrorMessage->((caller 0)[3], "une erreur a eu lieu lors de la generation du timestamp POSIX pour la date de debut et de fin de la derniere montee au plan."));
                        } else {
                            $_setObjProperty->($self, '_errorMessage', ($self->{'_errorMessage'} && $self->{'_errorMessage'} . ' ') . $_myErrorMessage->((caller 0)[3], "le champ 'ctm_daily_time' du datacenter '" . $datacenterInfos->{$dataCenter}->{'data_center'} . "' n'est pas correct " . '(=~ /^[\+\-]\d{4}$/).'));
                        }
                        return 0;
                    }
                }
                $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "erreur lors des jobs BIM : la methode DBI 'execute()' a echoue pour une ou plusieurs tables de l'active net : '" . join(' ', @activeNetTablesInError) . "'.")) if (@activeNetTablesInError);
                ($situation, my $servicesDatas) = $_getAllServices->($self->{'_DBI'}, exists $params{'matching'} ? $params{'matching'} : '%', \%jobsInformations, $datacenterInfos, exists $params{'forLastNetName'} ? $params{'forLastNetName'} : 0, $self->{'verbose'});
                $_setObjProperty->($self, '_errorMessage', ($self->{'_errorMessage'} && $self->{'_errorMessage'} . ' ') . $_myErrorMessage->((caller 0)[3], "la methode DBI 'execute()' a echoue pour les netnames suivants : '" . join(' ', @{$situation}) . "'.")) if (@{$situation});
                return $servicesDatas;
            } else {
                $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "erreur lors de la recuperation des informations a propos des ControlM Server : la methode DBI 'execute()' a echoue : '" . $self->{'_DBI'}->errstr() . "'."));
            }
        } else {
           $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de continuer car la connexion au SGBD n'est pas active."));
        }
        return 0;
    }

    sub countCurrentServices {
        Carp::croak($_myErrorMessage->((caller 0)[3], "la methode n'est pas correctement declaree.")) unless (@_ % 2);
        my ($self, %params) = (shift, @_);
        my $getCurrentServices = $self->getCurrentServices(
            'matching' => exists $params{'matching'} ? $params{'matching'} : '%',
            'forLastNetName' => exists $params{'forLastNetName'} ? $params{'forLastNetName'} : 0,
            'handleDeletedJobs' => exists $params{'handleDeletedJobs'} ? $params{'handleDeletedJobs'} : 1
        );
        ref $getCurrentServices eq 'HASH' ? return scalar keys %{$getCurrentServices} : return $getCurrentServices;
    }

    sub workOnCurrentServices {
        my $self = shift->$_WorkOnServicesConstructor(@_);
        Hash::Util::lock_hash(%{$self});
        return $self;
    }

    #-> accesseurs/mutateurs

    sub getSessionIsAlive {
        my $self = shift;
        if ($self->{'_DBI'} && $self->getSessionIsConnected()) {
            return $self->{'_DBI'}->ping();
        } else {
            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de tester l'etat de la connexion au SGBD car celle ci n'est pas active."));
            return 0;
        }
    }

    sub getSessionIsConnected {
        return shift->{'_sessionIsConnected'};
    }

    #-> Perl BuiltIn

    sub AUTOLOAD {
        my $self = shift;
        no strict qw/refs/;
        (my $called = $AUTOLOAD) =~ s/.*:://;
        Carp::croak("'" . $AUTOLOAD . "' : la methode '" . $called . "()' n'existe pas.") unless (exists $self->{$called});
        return $self->{$called};
    }

    sub DESTROY {
        my $self = shift;
        $self->disconnectFromDB();
        $_sessionsState{'nbSessionsInstanced'}--;
    }
}

#-> ** classe du constructeur ControlM::EM::BIM::ServicesAPI::workOnCurrentServices() **

{
    #----> ** initialisation **

    package _WorkOnServices;

    use base qw/ControlM::EM::BIM::ServicesAPI::Common ControlM::EM::BIM::ServicesAPI/;

    #----> ** variables de classe **

    our $AUTOLOAD;

    #----> ** fonctions privees **

    my $_getAllViaLogID = sub {
        my ($dbh, $sqlRequest, $verbose, @servicesLogID) = @_;
        $sqlRequest .= " WHERE log_id IN ('" . join("', '", @servicesLogID) . "');";
        print "> VERBOSE - \$_getAllViaLogID->() :\n\n" . $sqlRequest . "\n" if ($verbose);
        my $sth = $dbh->prepare($sqlRequest);
        if ($sth->execute()) {
            return 1, $sth->fetchall_hashref('log_id');
        } else {
            return 0, 0;
        }
    };

    my $_myErrorMessage = sub {
        my ($nameSpace, $message) = @_;
        return "'" . $nameSpace . "()' : " . $message;
    };

    #----> ** methodes privees **

    my $_setObjProperty = sub {
        my ($self, $property, $value) = @_;
        Hash::Util::unlock_value(%{$self}, $property);
        $self->{$property} = $value;
        Hash::Util::lock_value(%{$self}, $property);
        return 1;
    };

    #----> ** methodes publiques **

    #-> methodes liees aux services

    sub refresh {
        my $self = shift;
        while ($self->{'_working'}) {
            my $selfTemp = $self->{'_ControlM::EM::BIM::ServicesAPI'}->workOnCurrentServices();
            if (defined $self->{'_ControlM::EM::BIM::ServicesAPI'}->{'_errorMessage'}) {
                $_setObjProperty->($self, '_errorMessage', $self->{'_ControlM::EM::BIM::ServicesAPI'}->{'_errorMessage'});
                return 0;
            } else {
                $self->{'_ControlM::EM::BIM::ServicesAPI'}->clearError();
                $_setObjProperty->($selfTemp, '_errorMessage', $self->{'_errorMessage'});
                Hash::Util::unlock_hash(%{$self});
                $self = $selfTemp;
                Hash::Util::lock_hash(%{$self});
                return 1;
            }
        }
    }

    sub getSOAPEnvelopeForServices {
        my $self = shift;
        $_setObjProperty->($self, '_working', 1);
        if ($self->{'_currentServices'}) {
            my $XMLStr = <<XML;
<?xml version="1.0" encoding="iso-8859-1"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
    <SOAP-ENV:Body>
        <ctmem:response_bim_services_info xmlns:ctmem="http://www.bmc.com/it-solutions/product-listing/control-m-enterprise-manager.html">
            <ctmem:status>OK</ctmem:status>
            <ctmem:services>
XML
            for (keys %{$self->{'_currentServices'}}) {
                $XMLStr .= <<XML;
                <ctmem:service>
XML
                while (my ($key, $value) = each %{$self->{'_currentServices'}->{$_}}) {
                    if (defined $value) {
                        $XMLStr .= <<XML;
                    <ctmem:$key>$value</ctmem:$key>
XML
                    }
                }
                $XMLStr .= <<XML;
                </ctmem:service>
XML
            }
            $XMLStr .= <<XML;
            </ctmem:services>
        </ctmem:response_bim_services_info>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
XML
            chomp $XMLStr;
            $_setObjProperty->($self, '_working', 0);
            return \$XMLStr;
        } else {
            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de generer le XML, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."));
            $_setObjProperty->($self, '_working', 0);
            return 0;
        }
    }

    sub getAlertsByServices {
        my $self = shift;
        $_setObjProperty->($self, '_working', 1);
        if ($self->{'_ControlM::EM::BIM::ServicesAPI'}->getSessionIsConnected()) {
            if ($self->{'_currentServices'}) {
                if (my @servicesLogID = keys %{$self->{'_currentServices'}}) {
                    my ($situation, $hashRefPAlertsJobsForServices) = $_getAllViaLogID->($self->{'_ControlM::EM::BIM::ServicesAPI'}->{'_DBI'}, 'SELECT * FROM bim_alert', $self->{'_ControlM::EM::BIM::ServicesAPI'}->{'verbose'}, @servicesLogID);
                    if ($situation) {
                        $_setObjProperty->($self, '_working', 0);
                        return $hashRefPAlertsJobsForServices;
                    } else {
                        $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "erreur lors de la recuperation de la liste des jobs : la methode DBI 'execute()' a echouee : '" . $self->{'_ControlM::EM::BIM::ServicesAPI;'}->{'_DBI'}->errstr() . "'."));
                    }
                } else {
                    $_setObjProperty->($self, '_working', 0);
                    return {};
                }
            } else {
                $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de recuperer les alertes, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."));
            }
        } else {
            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de continuer car la connexion au SGBD n'est pas active."));
        }
        $_setObjProperty->($self, '_working', 0);
        return 0;
    }

    sub getProblematicsJobsByServices {
        my $self = shift;
        $_setObjProperty->($self, '_working', 1);
        if ($self->{'_ControlM::EM::BIM::ServicesAPI'}->getSessionIsConnected()) {
            if ($self->{'_currentServices'}) {
                if (my @servicesLogID = keys %{$self->{'_currentServices'}}) {
                    my ($situation, $hashRefProblematicsJobsForServices) = $_getAllViaLogID->($self->{'_ControlM::EM::BIM::ServicesAPI'}->{'_DBI'}, $self->{'_ControlM::EM::BIM::ServicesAPI'}->{'verbose'}, 'SELECT * FROM bim_prob_jobs', @servicesLogID);
                    if ($situation) {
                        $_setObjProperty->($self, '_working', 0);
                        return $hashRefProblematicsJobsForServices;
                    } else {
                        $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "erreur lors de la recuperation de la liste des jobs : la methode DBI 'execute()' a echouee : '" . $self->{'_ControlM::EM::BIM::ServicesAPI;'}->{'_DBI'}->errstr() . "'."));
                    }
                } else {
                    $_setObjProperty->($self, '_working', 0);
                    return {};
                }
            } else {
                $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de recuperer les jobs en erreur, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."));
            }
        } else {
            $_setObjProperty->($self, '_errorMessage', $_myErrorMessage->((caller 0)[3], "impossible de continuer car la connexion au SGBD n'est pas active."));
        }
        $_setObjProperty->($self, '_working', 0);
        return 0;
    }

    #-> Perl BuiltIn

    sub AUTOLOAD {
        my $self = shift;
        no strict qw/refs/;
        (my $called = $AUTOLOAD) =~ s/.*:://;
        Carp::croak("'" . $AUTOLOAD . "' : la methode '" . $called . "()' n'existe pas.") unless (exists $self->{$called});
        return $self->{$called};
    }

    sub DESTROY {
        my $self = shift;
        Hash::Util::unlock_hash(%{$self});
    }
}

1;

#-> END

__END__

=pod

=head1 NOM

ControlM::EM::BIM::ServicesAPI;

=head1 SYNOPSIS

Module pour consultation des services du Batch Impact Manager (BIM) ControlMEM v6/7/8

=head1 DEPENDANCES

ControlM::EM::BIM::ServicesAPI::Common, Carp, Hash::Util, Exporter, Time::Local, POSIX, DBI, /^DBD::(Pg|mysql|Oracle|Sybase|ODBC)$/

=head1 PROPRIETES PUBLIQUES (classe ControlM::EM::BIM::ServicesAPI)

=over

=item - $session->I<{DBMSType}>

Type de SGBD du ControlMEM auquel se connecter.

Les valeurs acceptees sont "Pg", "Oracle", "mysql", "Sybase" et "ODBC". Pour une connexion a MS SQL Server, les drivers "Sybase" et "ODBC" fonctionnent.

=item - $session->I<{DBMSAddress}>

Adresse du SGBD du ControlMEM auquel se connecter.

=item - $session->I<{DBMSPort}>

Port du SGBD du ControlMEM auquel se connecter.

=item - $session->I<{DBMSInstance}>

Instance (ou base) du SGBD du ControlMEM auquel se connecter.

=item - $session->I<{DBMSUser}>

Utilisateur du SGBD du ControlMEM auquel se connecter.

=item - $session->I<{DBMSPassword}>

Mot de passe du SGBD du ControlMEM auquel se connecter.

=item - $session->I<{DBMSTimeout}>

Timeout (en seconde) de la tentavive de connexion au SGBD du ControlMEM.

La valeur 0 signifie qu aucun timeout ne sera applique.

Attention, cette propriete risque de ne pas fonctionner sous Windows (ou d autres systemes ne gerant pas les signaux UNIX).

=item - $session->I<{verbose}>

Active la verbose du module, affiche les requetes SQL executees.

Ce parametre est un booleen. Si il est vrai alors cette methode ne retournera que les services avec la derniere ODATE. Faux par defaut.

=back

=head1 FONCTIONS PUBLIQUES (classe ControlM::EM::BIM::ServicesAPI)

=over

=item - getStatusColorForService()

Cette fonction permet de convertir le champ "status_to" de la table de hachage generee par la methode getCurrentServices() (et ses derives) en un status clair et surtout comprehensible ("OK", "Completed OK", "Completed Late", "Warning", "Error").

L entier du champ "status_to" ou la reference vers un service ($servicesHashRef->{1286} par exemple) recupere depuis la methode getCurrentServices() peuvent etres passes en parametre.

Retourne 0 si le parametre fourni n est pas correct (nombre non repertorie).

=item - getNbSessionsCreated()

Retourne le nombre d instances en cours pour la classe ControlM::EM::BIM::ServicesAPI.

=item - getNbSessionsConnected()

Retourne le nombre d instances en cours et connectees a la base du ControlMEM pour la classe ControlM::EM::BIM::ServicesAPI.

=back

=head1 METHODES PUBLIQUES (classe ControlM::EM::BIM::ServicesAPI)

=over

=item - my $session = ControlM::EM::BIM::ServicesAPI->newSession()

Cette methode est le constructeur de la classe ControlM::EM::BIM::ServicesAPI. ControlM::EM::BIM::ServicesAPI->new() est un equivalent.

Les parametres disponibles sont "ctmEMVersion", "DBMSType", "DBMSAddress", "DBMSPort", "DBMSInstance", "DBMSUser", "DBMSPassword", "DBMSTimeout" et "verbose" (booleen)

Pour information, le destructeur DESTROY() est appele lorsque toutes les references a l objet instancie ont ete detruites ("undef $session;" par exemple).

Retourne toujours un objet.

=item - $session->connectToDB()

Permet de se connecter a la base du ControlMEM avec les parametres fournis au constructeur newSession().

Retourne 1 si la connexion a reussi sinon 0.

=item - $session->disconnectFromDB()

Permet de se deconnecter de la base du ControlMEM mais elle n apelle pas le destructeur DESTROY().

Retourne 1 si la connexion a reussi sinon 0.

=item - $session->getCurrentServices()

Retourne une reference de la table de hachage de la liste des services en cours dans le Batch Impact Manager (BIM).

Un filtre est disponible avec le parametre "matching" (SQL LIKE clause).

Le parametre "forLastNetName" est un booleen. Si il est vrai alors cette methode ne retournera que les services avec la derniere ODATE. Faux par defaut.

Le parametre "handleDeletedJobs" est un booleen. Si il est vrai alors cette methode ne retournera que les services qui n ont pas ete supprimes du plan. Vrai par defaut.

La cle de cette table de hachage est "log_id".

Retourne 0 si la methode a echouee.

=item - $session->countCurrentServices()

Retourne le nombre de services actuellement en cours dans le Batch Impact Manager (BIM).

Derive de la methode $session->getCurrentServices(), elle herite donc de ses parametres.

Retourne 0 si la methode a echouee.

=item - my $workOnServices = $session->workOnCurrentServices()

Derive de la methode $session->getCurrentServices(), elle herite donc de ses parametres.

Retourne toujours un objet.

Fonctionne de la meme maniere que la methode $session->getCurrentServices() mais elle est surtout le constructeur de la classe _WorkOnServices qui met a disposition les methodes suivantes :

=over

=item - $workOnServices->refresh()

Rafraichi l objet "$workOnServices".

Retourne 1 si le rafraichissement a fonctionne ou 0 si celui-ci a echoue.

=item - $workOnServices->getSOAPEnvelopeForServices()

Retourne une reference vers une chaine de caractere au format XML (enveloppe SOAP de la liste des services du BIM).

Retourne 0 si la methode a echouee.

=item - $workOnServices->getProblematicsJobsByServices()

Retourne une reference vers une table de hachage qui contient la liste des jobs ControlM problematiques pour chaque "log_id".

Retourne 0 si la methode a echouee.

=item - $workOnServices->getAlertsByServices()

Retourne une reference vers une table de hachage qui contient la liste des alertes pour chaque "log_id".

Retourne 0 si la methode a echouee.

=back

=item - $session->getSessionIsAlive()

Verifie et retourne l etat (booleen) de la connexion a la base du ControlMEM.

Attention, n est pas fiable pour tous les types de SGBD (pour plus de details, voir B<http://search.cpan.org/dist/DBI/DBI.pm#ping>).

=item - $session->getSessionIsConnected()

Retourne l etat (booleen) de la connexion a la base du ControlMEM.

=back

=head1 METHODES PUBLIQUES (communes aux classes ControlM::EM::BIM::ServicesAPI ET _WorkOnServices)

=over

=item - $obj->I<getProperty($propertyName)>

Retourne la valeur de la propriete "$propertyName".

Leve une exception (warn) si celle-ci n existe pas et retourne 0.

=item - $obj->I<setPublicProperty($propertyName, $value)>

Remplace la valeur de la propriete publique "$propertyName" par "$value".

Retourne 1 si la valeur de la propriete a ete modifiee.

Leve une exception si c est une propriete privee ou si celle-ci n existe pas et retourne 0.

=item - $obj->getError()

Retourne la derniere erreur generee (plusieurs erreurs peuvent etre presentes dans la meme chaine de caracteres retournee).

Retourne undef si il n y a pas d erreur ou si la derniere a ete nettoyee via la methode $obj->clearError().

Une partie des erreurs sont fatales (notamment le fait de ne pas correctement utiliser les methodes/fonctions)).

=item - $obj->clearError()

Remplace la valeur de la derniere erreur generee par undef.

Retourne toujours 1.

=back

=head1 QUELQUES EXEMPLES ...

=over

=item - Afficher la version du module :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM::EM::BIM::ServicesAPI qw/$VERSION/;

    print $VERSION;

=item - Initialiser une session au Batch Impact Manager (BIM) du ControlMEM, s y connecter et afficher le nombre de services "%ERP%" courants :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM::EM::BIM::ServicesAPI;

    my $err;

    my $session = ControlM::EM::BIM::ServicesAPI->newSession(
        "ctmEMVersion" => 7,
        "DBMSType" => "Pg",
        "DBMSAddress" => "127.0.0.1",
        "DBMSPort" => 3306,
        "DBMSInstance" => "ControlM::EM",
        "DBMSUser" => "root",
        "DBMSPassword" => "root"
    );

    $session->connectToDB() || die $session->getError();

    my $nbServices = $sesion->countCurrentServices(
        "matching" => "%ERP%"
    );

    defined ($err = $session->getError()) ? die $err : print "Il y a " . $nbServices . " *ERP* courants .\n";

=item - Initialiser plusieurs sessions :

    #!/usr/bin/perl

    use strict;
    use warnings;
    use ControlM::EM::BIM::ServicesAPI qw/getNbSessionsCreated/;

    my %sessionParams = (
        "ctmEMVersion" => 7,
        "DBMSType" => "Pg",
        "DBMSAddress" => "127.0.0.1",
        "DBMSPort" => 3306,
        "DBMSInstance" => "ControlM::EM",
        "DBMSUser" => "root",
        "DBMSPassword" => "root"
    );

    my $session1 = ControlM::EM::BIM::ServicesAPI->newSession(%sessionParams);
    my $session2 = ControlM::EM::BIM::ServicesAPI->newSession(%sessionParams);

    print getNbSessionsCreated(); # affiche "2"

=item - Recupere et affiche la liste des services actuellement en cours dans le Batch Impact Manager (BIM) du ControlMEM :

    # [...]

    use ControlM::EM::BIM::ServicesAPI qw/getStatusColorForService/;

    # [...]

    $session->connectToDB() || die $session->getError();

    my $servicesHashRef = $session->getCurrentServices();

    unless (defined ($err = $session->getError())) {
        print $_->{service_name} . " : " . getStatusColorForService($_) . "\n" for (values %{$servicesHashRef})
    } else {
        die $err;
    }

=item - Recupere et affiche l enveloppe SOAP des services actuellement en cours dans le Batch Impact Manager (BIM) du ControlMEM :

    # [...]

    $session->connectToDB() || die $session->getError();

    my $workOnServices = $session->workOnCurrentServices();

    unless (defined ($err = $session->getError())) {
        my $xmlString = $workOnServices->getSOAPEnvelopeForServices();

        die $err if (defined ($err = $session->getError()));

        print $xmlString . "\n";
    } else {
        die $err;
    }

=back

=head1 ATTENTION

=over

=item - Ce module se base en partie sur l heure du systeme qui le charge. Si celle ci est fausse, certains resultats se retrouveront faux.

=item - Ce module ne s interface pas avec CORBA mais utilise le SGBD du ControlMEM.

=item - Les methodes, fonctions, proprietes, variables, ... prefixees de "_" sont privees.

=back

=head1 REMARQUES

=over

=item - La gestion de la version 6 de ControlMEM est encore experimentale en version 0.11x et -.

=item - Les mecanismes privees de ce module ne sont pas proteges de l utilisateur en version 0.12x et -.

=back

=head1 AUTEUR

Le Garff Yoann <pe.weeble@yahoo.fr>

=head1 LICENCE

Voir licence Perl.

=cut