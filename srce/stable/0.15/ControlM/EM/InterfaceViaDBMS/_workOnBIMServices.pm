#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Module du constructeur ControlM::EM::InterfaceViaDBMS::workOnCurrentServices()
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlMEM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 22/05/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE / AIDE
#   perldoc ControlM::EM::InterfaceViaDBMS::_workOnBIMServices
#
# DEPENDANCES OBLIGATOIRES
#   - 'ControlM::EM::Base'
#   - 'ControlM::EM::InterfaceViaDBMS'
#   - 'Carp'
#   - 'Hash::Util'
#==========================================================================================================

#-> BEGIN

#----> ** initialisation **

package ControlM::EM::InterfaceViaDBMS::_workOnBIMServices;

use strict;
use warnings;

use base qw/ControlM::EM::Base Exporter/;

use Carp;
use Hash::Util;

#----> ** variables de classe **

our $AUTOLOAD;
our $VERSION = 0.15;

#----> ** fonctions privees (mais accessibles a l'utilisateur) **

sub _getAllViaLogID(\$$$@) {
    my ($dbh, $sqlRequest, $verbose, @servicesLogID) = @_;
    $sqlRequest .= " WHERE log_id IN ('" . join("', '", @servicesLogID) . "');";
    print "> VERBOSE - _getAllViaLogID() :\n\n" . $sqlRequest . "\n" if ($verbose);
    my $sth = $dbh->prepare($sqlRequest);
    if ($sth->execute()) {
        return 1, $sth->fetchall_hashref('log_id');
    } else {
        return 0, 0;
    }
}

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
    while ($self->{_working}) {
        my $selfTemp = $self->{'_ControlM::EM::InterfaceViaDBMS'}->workOnCurrentServices();
        if (defined $self->{'_ControlM::EM::InterfaceViaDBMS'}->{_errorMessage}) {
            $_setObjProperty->($self, '_errorMessage', $self->{'_ControlM::EM::InterfaceViaDBMS'}->{_errorMessage});
            return 0;
        } else {
            $self->{'_ControlM::EM::InterfaceViaDBMS'}->clearError();
            $_setObjProperty->($selfTemp, '_errorMessage', $self->{_errorMessage});
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
    if ($self->{_currentServices}) {
        my $XMLStr = <<XML;
<?xml version="1.0" encoding="iso-8859-1"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
<SOAP-ENV:Body>
    <ctmem:response_bim_services_info xmlns:ctmem="http://www.bmc.com/it-solutions/product-listing/control-m-enterprise-manager.html">
        <ctmem:status>OK</ctmem:status>
        <ctmem:services>
XML
        for (keys %{$self->{_currentServices}}) {
            $XMLStr .= <<XML;
            <ctmem:service>
XML
            while (my ($key, $value) = each %{$self->{_currentServices}->{$_}}) {
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
        $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "impossible de generer le XML, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."));
        $_setObjProperty->($self, '_working', 0);
        return 0;
    }
}

sub getAlertsByServices {
    my $self = shift;
    $_setObjProperty->($self, '_working', 1);
    if ($self->{'_ControlM::EM::InterfaceViaDBMS'}->getSessionIsConnected()) {
        if ($self->{_currentServices}) {
            if (my @servicesLogID = keys %{$self->{_currentServices}}) {
                my ($situation, $hashRefPAlertsJobsForServices) = _getAllViaLogID($self->{'_ControlM::EM::InterfaceViaDBMS'}->{_DBI}, 'SELECT * FROM bim_alert', $self->{'_ControlM::EM::InterfaceViaDBMS'}->{verbose}, @servicesLogID);
                if ($situation) {
                    $_setObjProperty->($self, '_working', 0);
                    return $hashRefPAlertsJobsForServices;
                } else {
                    $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "erreur lors de la recuperation de la liste des jobs : la methode DBI 'execute()' a echouee : '" . $self->{'_ControlM::EM::InterfaceViaDBMS'}->{_DBI}->errstr() . "'."));
                }
            } else {
                $_setObjProperty->($self, '_working', 0);
                return {};
            }
        } else {
            $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "impossible de recuperer les alertes, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."));
        }
    } else {
        $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "impossible de continuer car la connexion au SGBD n'est pas active."));
    }
    $_setObjProperty->($self, '_working', 0);
    return 0;
}

sub getProblematicsJobsByServices {
    my $self = shift;
    $_setObjProperty->($self, '_working', 1);
    if ($self->{'_ControlM::EM::InterfaceViaDBMS'}->getSessionIsConnected()) {
        if ($self->{_currentServices}) {
            if (my @servicesLogID = keys %{$self->{_currentServices}}) {
                my ($situation, $hashRefProblematicsJobsForServices) = _getAllViaLogID($self->{'_ControlM::EM::InterfaceViaDBMS'}->{_DBI}, $self->{'_ControlM::EM::InterfaceViaDBMS'}->{verbose}, 'SELECT * FROM bim_prob_jobs', @servicesLogID);
                if ($situation) {
                    $_setObjProperty->($self, '_working', 0);
                    return $hashRefProblematicsJobsForServices;
                } else {
                    $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "erreur lors de la recuperation de la liste des jobs : la methode DBI 'execute()' a echouee : '" . $self->{'_ControlM::EM::InterfaceViaDBMS'}->{_DBI}->errstr() . "'."));
                }
            } else {
                $_setObjProperty->($self, '_working', 0);
                return {};
            }
        } else {
            $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "impossible de recuperer les jobs en erreur, les services n'ont pas pu etre generer via la methode 'workOnCurrentServices()'."));
        }
    } else {
        $_setObjProperty->($self, '_errorMessage', ControlM::EM::Base::_myErrorMessage((caller 0)[3], "impossible de continuer car la connexion au SGBD n'est pas active."));
    }
    $_setObjProperty->($self, '_working', 0);
    return 0;
}

#-> Perl BuiltIn

sub DESTROY {
    my $self = shift;
    Hash::Util::unlock_hash(%{$self});
}

#-> END

__END__

=pod

=head1 NOM

ControlM::EM::Base

=head1 SYNOPSIS

Module du constructeur ControlM::EM::InterfaceViaDBMS::workOnCurrentServices().
Pour plus de details, voir la documention de ControlM::EM::InterfaceViaDBMS.

=head1 DEPENDANCES

ControlM::EM::Base, ControlM::EM::InterfaceViaDBMS, Carp, Hash::Util

=head1 ATTENTION

Ce module est dedie au module ControlM::EM::InterfaceViaDBMS et ne doit pas etre utilise autrement.

=head1 AUTEUR

Le Garff Yoann <pe.weeble@yahoo.fr>

=head1 LICENCE

Voir licence Perl.

=cut