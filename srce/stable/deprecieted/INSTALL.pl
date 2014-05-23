#!/usr/bin/perl
#@(#)------------------------------------------------------------------------------------------------------
#@(#) OBJET : Installateur du module ControlM::EM::BIM::ServicesAPI
#@(#)------------------------------------------------------------------------------------------------------
#@(#) APPLICATION : ControlMEM + Batch Impact Manager (BIM)
#@(#)------------------------------------------------------------------------------------------------------
#@(#) AUTEUR : Yoann Le Garff
#@(#) DATE DE CREATION : 17/04/2014
#@(#) VERSION : 1.0
#@(#) ETAT : STABLE
#@(#)------------------------------------------------------------------------------------------------------

#==========================================================================================================
# USAGE
#   ./INSTALL.pl <chemin vers le module ServicesAPI.pm (case sensitive)> [<verbose : 0/1>]
#
# DEPENDANCES OBLIGATOIRES
#   - 'File::Path'
#   - 'File::Copy'
#=======================================================================================================

#-> BEGIN

#----> ** chargement des modules **

use strict;
use warnings;

use File::Path qw/make_path/;
use File::Copy;

#----> ** gestion des arguments **

die 'Usage : ' . $0 . ' <chemin vers le module ServicesAPI.pm (case sensitive)> [<verbose : 0/1>]' unless (@ARGV >= 1 && $ARGV[0] =~ /ServicesAPI.pm$/ && -f $ARGV[0]);

$ARGV[1] = 0 unless (defined $ARGV[1] && $ARGV[1] =~ /^[01]$/);

#----> ** fonctions **

sub prefixTimeValueWithZero($) {
    return ((length $_[0] == 1) && '0') . $_[0];
}

sub printWithTime($) {
    my ($sec, $min, $hour, $day, $mon, $year) = localtime time;
    print '[' . ($year + 1900) . '/' . prefixTimeValueWithZero($mon)  . '/' . prefixTimeValueWithZero($day) . ' ' . prefixTimeValueWithZero($hour) . ':' . prefixTimeValueWithZero($mon) . ':' . prefixTimeValueWithZero($sec) . '] - ' . $_[0] . "\n";
}

#----> ** declaration des variables **

BEGIN {
    *subDirName = sub { return 'ServicesAPI' };
}

my $moduleName = 'ControlM::EM::BIM::ServicesAPI';
my ($errors, $makePathErrors, @moduleDeps, @moduleDepsInErrors, @subsModules);
my @argsZeroItemsPath = split /[\\\/]/, $ARGV[0];
my $argsZeroDirPath = join '/', @argsZeroItemsPath[0..@argsZeroItemsPath-2];
my @moduleItemsPath = split /::/, $moduleName;
my $moduleDirPath = join '/', @moduleItemsPath[0..@moduleItemsPath-2];

#----> ** verification des dependances **

open my $fHandler, '<', $ARGV[0] || die printWithTime("Le fichier '" . $ARGV[0] . "' n'a pas pu etre ouvert ('" . $! . "'), impossible de continuer l'installation du module '" . $moduleName . "'.");

while (<$fHandler>) {
    last if (/^__END__/);
    chomp;
    s/^\s+//g;
    push @moduleDeps, (split /\s+/)[1] if (/^use\s/);
}

close $fHandler || die printWithTime("Le fichier '" . $ARGV[0] . "' n'a pas pu etre fermer ('" . $! . "'), impossible de continuer l'installation du module '" . $moduleName . "'.");

for (@moduleDeps) {
    if (/^[A-Z]/) {
        chop if (/;$/);
        unless (/^${moduleName}::/) {
            if (eval 'require ' . $_) {
                printWithTime("Verification de la dependance (module) '" . $_ . "' : OK.");
            } else {
                printWithTime("Verification de la dependance (module) '" . $_ . "' : NOK.");
                push @moduleDepsInErrors, $_;
            }
        } else {
            push @subsModules, (split /::/)[-1];
        }
    }
}

die printWithTime("Une ou plusieurs dependances (modules) sont manquantes, impossible de continuer l'installation du module '" . $moduleName . "'.") if (@moduleDepsInErrors);

#----> ** principale **

for (@INC) {
    unless (/^.$/) {
        my $completeDirPath = $_ . '/' . $moduleDirPath;
        my $completePath = $completeDirPath . '/' . $moduleItemsPath[-1] . '.pm';
        my %subsModulesCompletePath;
        for (@subsModules) {
            $subsModulesCompletePath{$argsZeroDirPath . '/' . subDirName .  '/' . $_ . '.pm'} = $completeDirPath . '/' . subDirName .  '/' . $_ . '.pm';
        }
        if (-d $completeDirPath . '/' . subDirName) {
            printWithTime("Le repertoire '" . $completeDirPath . '/' . subDirName . "' existe deja : OK.");
        } else {
            printWithTime("Creation du repertoire '" . $completeDirPath . '/' . subDirName . "' : OK.");
            make_path(
                $completeDirPath . '/' . subDirName, {
                    verbose => $ARGV[1],
                    error => \$makePathErrors
                }
            );
        }
        if (ref $makePathErrors && @{$makePathErrors}) {
            printWithTime('Une ou plusieurs erreurs ont ete detectees lors de File::Path::make_path(' . $completeDirPath . '/' . subDirName . ') : NOK.');
            $errors++;
        } else {
            if (copy($ARGV[0], $completePath)) {
                printWithTime("Module '" . $ARGV[0] . "' -> '" . $completePath . "' copie : OK.");
            } else {
                printWithTime("Erreur lors de la copie de '" . $ARGV[0] . "' -> '" . $completePath . "' : NOK.");
                $errors++;
            }
            while (my ($source, $destination) = each %subsModulesCompletePath) {
                if (copy($source, $destination)) {
                    printWithTime("Module '" . $source . "' -> '" . $destination . "' copie : OK.");
                } else {
                    printWithTime("Erreur lors de la copie de '" . $source . "' -> '" . $destination . "' : NOK.");
                    $errors++;
                }
            }
        }
    }
}

if ($errors) {
    printWithTime('NOK - Une ou plusieurs erreurs (' . $errors . ") ont ete detectes durant l'installation. Il se peut que le module ne soit pas fonctionnel.");
    exit 1;
} else {
    printWithTime("OK - L'operation s'est correctement deroulee.");
    exit 0;
}

#-> END