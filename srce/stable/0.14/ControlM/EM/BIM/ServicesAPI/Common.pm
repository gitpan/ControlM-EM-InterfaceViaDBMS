#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Classe abstraite des classes de ServicesAPI.pm
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlMEM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 09/05/2014
#@(#) ETAT : 1.0
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE / AIDE
#   perldoc ControlM::EM::BIM::ServicesAPI::Common
#
# ATTENTION
#   Ce module est dedie au module ControlM::EM::BIM::ServicesAPI et n'a pas a etre utilise autrement.
#==========================================================================================================

{
    #----> ** initialisation **

    package ControlM::EM::BIM::ServicesAPI::Common;

    use strict;
    use warnings;

    use Exporter;
    use Carp;
    use Hash::Util;

    #----> ** variables de classe **

    our $VERSION = 0.14;
    our @EXPORT_OK = qw/$VERSION/;

    #----> ** fonctions/methodes privees **

    my $_setObjProperty = sub {
        my ($self, $property, $value) = @_;
        Hash::Util::unlock_value(%{$self}, $property);
        $self->{$property} = $value;
        Hash::Util::lock_value(%{$self}, $property);
        return 1;
    };

    my $_myErrorMessage = sub {
        my ($nameSpace, $message) = @_;
        return "'" . $nameSpace . "()' : " . $message;
    };

    #----> ** fonctions/methodes destinees a etre publiques **

    sub getProperty {
        my ($self, $property) = @_;
        if (exists $self->{$property}) {
            return $self->{$property};
        } else {
            Carp::carp($_myErrorMessage->((caller 0)[3], "propriete ('" . $property . "') inexistante."));
            return 0;
        }
    }

    sub setPublicProperty {
        my ($self, $property, $value) = @_;
        unless (exists $self->{$property}) {
            Carp::carp($_myErrorMessage->((caller 0)[3], "tentative de creation d'une propriete ('" . $property . "')."));
        } elsif ($property =~ /^_/) {
            Carp::carp($_myErrorMessage->((caller 0)[3], "tentative de modication d'une propriete ('" . $property . "') privee."));
        }
        return $_setObjProperty->($self, $property, $value);
    }

    sub getError {
        return $self->getProperty('_errorMessage');
    }

    sub clearError {
        return $_setObjProperty->(shift, '_errorMessage', undef);
    }
}

1;

__END__

=pod

=head1 NOM

ControlM::EM::BIM::ServicesAPI::Common;

=head1 SYNOPSIS

Classe abstraite des classes de ServicesAPI.pm

=head1 ATTENTION

Ce module est dedie au module ControlM::EM::BIM::ServicesAPI et n a pas a etre utilise autrement.

=head1 AUTEUR

Le Garff Yoann <pe.weeble@yahoo.fr>

=head1 LICENCE

Voir licence Perl.

=cut