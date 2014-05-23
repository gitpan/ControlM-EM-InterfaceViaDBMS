#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Installation de ControlM::EM::InterfaceViaDBMS et de ses dependances
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlMEM
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 16/05/2014
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE
#   perl Makefile.PL
#
# DEPENDANCES OBLIGATOIRES
#   - 'ExtUtils::MakeMaker'
#==========================================================================================================

use ExtUtils::MakeMaker;

$MIN_PERL_VERSION = '5.6.1';

WriteMakefile(
    'NAME' => 'ControlM::EM::InterfaceViaDBMS',
    'AUTHOR' => 'Le Garff Yoann <pe.weeble@yahoo.fr>',
    'LICENSE' => 'perl',
    'VERSION_FROM' => 'lib/ControlM/EM/InterfaceViaDBMS.pm',
    'PREREQ_PM' => {
        'Carp' => 0,
        'Hash::Util' => 0,
        'Exporter' => 0,
        'Time::Local' => 0,
        'POSIX'  => 0,
        'DBI'  => 0
    },
    'clean' => {
      'FILES' => '*~',
    },
    'realclean' => {
      'FILES' => '*~',
    }
);