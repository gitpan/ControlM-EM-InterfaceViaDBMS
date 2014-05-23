#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : "Classe abstraite" des modules de ControlM::EM
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlMEM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 09/05/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE / AIDE
#   perldoc ControlM::EM::Base
#
# DEPENDANCES OBLIGATOIRES
#   - 'Carp'
#   - 'Hash::Util'
#   - 'Time::Local'
#
# ATTENTION
#   "Classe abstraite" des modules de ControlM::EM. Ce module n'a pas pour but d'etre charge par l'utilisateur
#==========================================================================================================

#-> BEGIN

#----> ** initialisation **

package ControlM::EM::Base;

require 5.6.1;

use strict;
use warnings;

use Carp;
use Hash::Util;
use Time::Local;

#----> ** variables de classe **

our $VERSION = 0.15;

#----> ** fonctions privees **

my $_setObjProperty = sub {
    my ($self, $property, $value) = @_;
    Hash::Util::unlock_value(%{$self}, $property);
    $self->{$property} = $value;
    Hash::Util::lock_value(%{$self}, $property);
    return 1;
};

#-> privees mais accessibles a l'utilisateur)

sub _myOSIsUnix {
    return grep (/^${^O}$/i, qw/aix bsdos dgux dynixptx freebsd linux hpux irix openbsd dec_osf svr4 sco_sv svr4 unicos unicosmk solaris sunos netbsd sco3 ultrix macos rhapsody/);
}

sub _dateToPosixTimestamp {
    my ($year, $mon, $day, $hour, $min, $sec) = split /[\/\-\s:]+/, shift;
    my $time = timelocal($sec, $min, $hour, $day, $mon - 1 ,$year);
    return $time =~ /^\d+$/ ? $time : undef;
}

sub _myErrorMessage {
    my ($nameSpace, $message) = @_;
    return "'" . $nameSpace . "()' : " . $message;
}

#----> ** methodes destinees a etre publiques **

sub getProperty {
    my ($self, $property) = @_;
    if (exists $self->{$property}) {
        return $self->{$property};
    } else {
        Carp::carp(_myErrorMessage((caller 0)[3], "propriete ('" . $property . "') inexistante."));
        return 0;
    }
}

sub setPublicProperty {
    my ($self, $property, $value) = @_;
    unless (exists $self->{$property}) {
        Carp::carp(_myErrorMessage((caller 0)[3], "tentative de creation d'une propriete ('" . $property . "')."));
    } elsif ($property =~ /^_/) {
        Carp::carp(_myErrorMessage((caller 0)[3], "tentative de modication d'une propriete ('" . $property . "') privee."));
    }
    return $_setObjProperty->($self, $property, $value);
}

sub getError {
    return shift->getProperty('_errorMessage');
}

sub clearError {
    return $_setObjProperty->(shift, '_errorMessage', undef);
}

1;

#-> END

__END__

=pod

=head1 NOM

ControlM::EM::Base

=head1 SYNOPSIS

"Classe abstraite" des modules de ControlM::EM.
Pour plus de details, voir la documention de ControlM::EM::InterfaceViaDBMS.

=head1 DEPENDANCES

Carp, Hash::Util

=head1 ATTENTION

Ce module est dedie au module ControlM::EM::InterfaceViaDBMS et ne doit pas etre utilise autrement.

=head1 AUTEUR

Le Garff Yoann <pe.weeble@yahoo.fr>

=head1 LICENCE

Voir licence Perl.

=cut