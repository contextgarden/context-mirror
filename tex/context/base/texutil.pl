#!/usr/bin/perl  

#-w

#D \module
#D   [       file=texutil.pl,
#D        version=1997.12.08,
#D          title=pre- and postprocessing utilities,
#D       subtitle=\TEXUTIL,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This script is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. Non||commercial use is
#C granted.

#  Thanks to Tobias Burnus for the german translations.
#  Thanks to Taco Hoekwater for making the file -w proof. 

#D This is \TEXUTIL, a utility program (script) to be used
#D alongside the \CONTEXT\ macro package. This \PERL\ script is
#D derived from the \MODULA\ version and uses slightly better
#D algoritms for sanitizing \TEX\ specific (sub|)|strings.
#D This implementation is therefore not entirely compatible
#D with the original \TEXUTIL, although most users will
#D probably never notice. Now how was this program called?

$Program = "TeXUtil 6.40 - ConTeXt / PRAGMA 1992-1998" ;

#D By the way, this is my first \PERL\ script, which means
#D that it will be improved as soon as I find new and/or more
#D suitable solutions in the \PERL\ manuals. As can be seen in
#D the definition of \type{$program}, this program is part of
#D the \CONTEXT\ suite, and therefore can communicate with the
#D users in english as well as some other languages. One can
#D set his favourite language by saying something like:

#D \starttypen
#D perl texutil.pl --interface=de --figures *.eps *.tif
#D \stoptypen
#D
#D Of course one can also say \type{--interface=nl}, which
#D happens to be my native language.

#D I won't go into too much detail on the algoritms used.
#D The next few pages show the functionality as reported by the
#D helpinformation and controled by command line arguments
#D and can serve as additional documentation.

#D \TEXUTIL\ can handle different tasks; which one is active
#D depends on the command line arguments. Most task are
#D handled by the procedures below. The one exception is the
#D handling of \TIFF\ files when collecting illustration
#D files. When needed, \TEXUTIL\ calls for \TIFFINFO\ or
#D \TIFFTAGS, but more alternatives can be added by extending
#D \type{@TiffPrograms}.
 
@TiffPrograms = ("tiffinfo", "tifftags") ;

#D Back to the command line arguments. These are handled by
#D a \PERL\ system module. This means that, at least for the
#D moment, there is no external control as provided by the
#D \PRAGMA\ environment system.

use Getopt::Long ;

#D We don't want error messages and accept partial switches,
#D which saves users some typing.

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

#D We also predefine the interface language and set a boolean
#D that keeps track of unknown options. \voetnoot {This feature
#D is still to be implemented.}

$Interface      = "en" ;
$UnknownOptions = 0 ;

#D Here come the options:

&GetOptions
  ("references"     => \$ProcessReferences,
      "ij"                => \$ProcessIJ,
      "high"              => \$ProcessHigh,
      "quotes"            => \$ProcessQuotes,
   "documents"      => \$ProcessDocuments,
      "type=s"      => \$ProcessType,
   "sources"        => \$ProcessSources,
   "setups"         => \$ProcessSetups,
   "templates"      => \$ProcessTemplates,
   "infos"          => \$ProcessInfos,
   "figures"        => \$ProcessFigures,
      "tiff"              =>\$ProcessTiff,
   "logfile"        => \$ProcessLogFile,
      "box"               =>\$ProcessBox,
      "hbox"              =>\$ProcessHBox,
      "vbox"              =>\$ProcessVBox,
      "criterium=f"       =>\$ProcessCriterium,
      "unknown"           =>\$ProcessUnknown,
   "help"           => \$ProcessHelp,
   "interface=s"    => \$Interface) ;

#D By default wildcards are expanded into a list. The
#D subroutine below is therefore only needed when no file or
#D pattern is given.

$InputFile = "@ARGV" ;

sub CheckInputFiles
  { my ($UserSuppliedPath) = @_ ;
    @UserSuppliedFiles = map { split " " } sort lc $UserSuppliedPath }
 
#D In order to support multiple interfaces, we save the
#D messages in a hash table. As a bonus we can get a quick
#D overview of the messages we deal with.

sub Report
  { foreach $_ (@_)
      { if (! defined $MS{$_})
          { print $_ }
        else
          { print $MS{$_} }
        print " " }
    print "\n" }

#D The messages are saved in a hash table and are called
#D by name. This contents of this table depends on the
#D interface language in use.

#D \startcompressdefinitions

if ($Interface eq "nl")

  { # begin of dutch section

    $MS{"ProcessingReferences"}    = "commando's, lijsten en indexen verwerken" ;
    $MS{"GeneratingDocumentation"} = "ConTeXt documentatie file voorbereiden" ;
    $MS{"GeneratingSources"}       = "ConTeXt broncode file genereren" ;
    $MS{"FilteringDefinitions"}    = "ConTeXt definities filteren" ;
    $MS{"CopyingTemplates"}        = "TeXEdit toets templates copieren" ;
    $MS{"CopyingInformation"}      = "TeXEdit help informatie copieren" ;
    $MS{"GeneratingFigures"}       = "figuur file genereren" ;
    $MS{"FilteringLogFile"}        = "log file filteren (poor mans version)" ;

    $MS{"SortingIJ"}               = "IJ sorteren onder Y" ;
    $MS{"ConvertingHigh"}          = "hoge ASCII waarden converteren" ;
    $MS{"ProcessingQuotes"}        = "characters met accenten afhandelen" ;
    $MS{"ForcingFileType"}         = "filetype instellen" ;
    $MS{"UsingTiff"}               = "TIF files afhandelen" ;
    $MS{"FilteringBoxes"}          = "overfull boxes filteren" ;
    $MS{"ApplyingCriterium"}       = "criterium toepassen" ;
    $MS{"FilteringUnknown"}        = "onbekende ... filteren" ;

    $MS{"NoInputFile"}             = "geen invoer file opgegeven" ;
    $MS{"NoOutputFile"}            = "geen uitvoer file gegenereerd" ;
    $MS{"EmptyInputFile"}          = "lege invoer file" ;
    $MS{"NotYetImplemented"}       = "nog niet beschikbaar" ;

    $MS{"Action"}                  = "                 actie :" ;
    $MS{"Option"}                  = "                 optie :" ;
    $MS{"Error"}                   = "                  fout :" ;
    $MS{"Remark"}                  = "             opmerking :" ;
    $MS{"SystemCall"}              = "        systeemaanroep :" ;
    $MS{"BadSystemCall"}           = "  foute systeemaanroep :" ;
    $MS{"MissingSubroutine"}       = "  onbekende subroutine :" ;

    $MS{"EmbeddedFiles"}           = "       gebruikte files :" ;
    $MS{"BeginEndError"}           = "           b/e fout in :" ;
    $MS{"SynonymEntries"}          = "     aantal synoniemen :" ;
    $MS{"SynonymErrors"}           = "                fouten :" ;
    $MS{"RegisterEntries"}         = "       aantal ingangen :" ;
    $MS{"RegisterErrors"}          = "                fouten :" ;
    $MS{"PassedCommands"}          = "     aantal commando's :" ;

    $MS{"NOfDocuments"}            = "  documentatie blokken :" ;
    $MS{"NOfDefinitions"}          = "     definitie blokken :" ;
    $MS{"NOfSkips"}                = "  overgeslagen blokken :" ;
    $MS{"NOfSetups"}               = "    gecopieerde setups :" ;
    $MS{"NOfTemplates"}            = " gecopieerde templates :" ;
    $MS{"NOfInfos"}                = " gecopieerde helpinfos :" ;
    $MS{"NOfFigures"}              = "     verwerkte figuren :" ;
    $MS{"NOfBoxes"}                = "        te volle boxen :" ;
    $MS{"NOfUnknown"}              = "         onbekende ... :" ;

    $MS{"InputFile"}               = "           invoer file :" ;
    $MS{"OutputFile"}              = "          outvoer file :" ;
    $MS{"FileType"}                = "             type file :" ;
    $MS{"EpsFile"}                 = "              eps file :" ;
    $MS{"TifFile"}                 = "              tif file :" ;
    $MS{"MPFile"}                  = "         metapost file :" ;

    $MS{"Overfull"}                = "te vol" ;
    $MS{"Entries"}                 = "ingangen" ;
    $MS{"References"}              = "verwijzingen" ;

  } # end of dutch section

elsif ($Interface eq "de")

  { # begin of german section

    $MS{"ProcessingReferences"}    = "Verarbeiten der Befehle, Listen und Register" ;
    $MS{"GeneratingDocumentation"} = "Vorbereiten der ConTeXt-Dokumentationsdatei" ;
    $MS{"GeneratingSources"}       = "Erstellen einer nur Quelltext ConTeXt-Datei" ;
    $MS{"FilteringDefinitions"}    = "Filtern der ConTeXt-Definitionen" ;
    $MS{"CopyingTemplates"}        = "Kopieren der TeXEdit-Test-key-templates" ;
    $MS{"CopyingInformation"}      = "Kopieren der TeXEdit-Hilfsinformation" ;
    $MS{"GeneratingFigures"}       = "Erstellen einer Abb-Uebersichtsdatei" ;
    $MS{"FilteringLogFile"}        = "Filtern der log-Datei" ;

    $MS{"SortingIJ"}               = "Sortiere IJ nach Y" ;
    $MS{"ConvertingHigh"}          = "Konvertiere hohe ASCII-Werte" ;
    $MS{"ProcessingQuotes"}        = "Verarbeiten der Akzentzeichen" ;
    $MS{"ForcingFileType"}         = "Dateityp einstellen" ;
    $MS{"UsingTiff"}               = "TIF-Dateien verarbeite" ;
    $MS{"FilteringBoxes"}          = "Filtern der ueberfuellten Boxen" ;
    $MS{"ApplyingCriterium"}       = "Anwenden des uebervoll-Kriteriums" ;
    $MS{"FilteringUnknown"}        = "Filter unbekannt ..." ;

    $MS{"NoInputFile"}             = "Keine Eingabedatei angegeben" ;
    $MS{"NoOutputFile"}            = "Keine Ausgabedatei generiert" ; # TOBIAS 
    $MS{"EmptyInputFile"}          = "Leere Eingabedatei" ;
    $MS{"NotYetImplemented"}       = "Noch nicht verfuegbar" ;

    $MS{"Action"}                  = "                Aktion :" ;
    $MS{"Option"}                  = "                Option :" ;
    $MS{"Error"}                   = "                Fehler :" ;
    $MS{"Remark"}                  = "             Anmerkung :" ;
    $MS{"SystemCall"}              = "           system call :" ;
    $MS{"BadSystemCall"}           = "       bad system call :" ;
    $MS{"MissingSubroutine"}       = "    missing subroutine :" ;
    $MS{"SystemCall"}              = "          Systemaufruf :" ;
    $MS{"BadSystemCall"}           = "   Fehlerhafter Aufruf :" ;
    $MS{"MissingSubroutine"}       = " Fehlende Unterroutine :" ;

    $MS{"EmbeddedFiles"}           = "  Eingebettete Dateien :" ;
    $MS{"BeginEndError"}           = "   Beg./Ende-Fehler in :" ;
    $MS{"SynonymEntries"}          = "      Synonymeintraege :" ;
    $MS{"SynonymErrors"}           = " Fehlerhafte Eintraege :" ;
    $MS{"RegisterEntries"}         = "     Registereintraege :" ;
    $MS{"RegisterErrors"}          = " Fehlerhafte Eintraege :" ;
    $MS{"PassedCommands"}          = "    Verarbeite Befehle :" ;

    $MS{"NOfDocuments"}            = "       Dokumentbloecke :" ;
    $MS{"NOfDefinitions"}          = "    Definitionsbloecke :" ;
    $MS{"NOfSkips"}                = "Uebersprungene Bloecke :" ;
    $MS{"NOfSetups"}               = "       Kopierte setups :" ;
    $MS{"NOfTemplates"}            = "    Kopierte templates :" ;
    $MS{"NOfInfos"}                = "    Kopierte helpinfos :" ;
    $MS{"NOfFigures"}              = "     Verarbeitete Abb. :" ;
    $MS{"NOfBoxes"}                = "        Zu volle Boxen :" ;
    $MS{"NOfUnknown"}              = "         Unbekannt ... :" ;

    $MS{"InputFile"}               = "          Eingabedatei :" ;
    $MS{"OutputFile"}              = "          Ausgabedatei :" ;
    $MS{"FileType"}                = "              Dateityp :" ; 
    $MS{"EpsFile"}                 = "             eps-Datei :" ;
    $MS{"TifFile"}                 = "             tif-Datei :" ;
    $MS{"MPFile"}                  = "        metapost-Datei :" ;

    $MS{"Overfull"}                = "zu voll" ;
    $MS{"Entries"}                 = "Eintraege" ;
    $MS{"References"}              = "Referenzen" ;

  } # end of german section

else

  { # begin of english section

    $MS{"ProcessingReferences"}    = "processing commands, lists and registers" ;
    $MS{"GeneratingDocumentation"} = "preparing ConTeXt documentation file" ;
    $MS{"GeneratingSources"}       = "generating ConTeXt source only file" ;
    $MS{"FilteringDefinitions"}    = "filtering formal ConTeXt definitions" ;
    $MS{"CopyingTemplates"}        = "copying TeXEdit quick key templates" ;
    $MS{"CopyingInformation"}      = "copying TeXEdit help information" ;
    $MS{"GeneratingFigures"}       = "generating figure directory file" ;
    $MS{"FilteringLogFile"}        = "filtering log file" ;

    $MS{"SortingIJ"}               = "sorting IJ under Y" ;
    $MS{"ConvertingHigh"}          = "converting high ASCII values" ;
    $MS{"ProcessingQuotes"}        = "handling accented characters" ;
    $MS{"ForcingFileType"}         = "setting up filetype" ;
    $MS{"UsingTiff"}               = "processing TIF files" ;
    $MS{"FilteringBoxes"}          = "filtering overfull boxes" ;
    $MS{"ApplyingCriterium"}       = "applying overfull criterium" ;
    $MS{"FilteringUnknown"}        = "filtering unknown ..." ;

    $MS{"NoInputFile"}             = "no input file given" ;
    $MS{"NoOutputFile"}            = "no output file generated" ;
    $MS{"EmptyInputFile"}          = "empty input file" ;
    $MS{"NotYetImplemented"}       = "not yet available" ;

    $MS{"Action"}                  = "                action :" ;
    $MS{"Option"}                  = "                option :" ;
    $MS{"Error"}                   = "                 error :" ;
    $MS{"Remark"}                  = "                remark :" ;
    $MS{"SystemCall"}              = "           system call :" ;
    $MS{"BadSystemCall"}           = "       bad system call :" ;
    $MS{"MissingSubroutine"}       = "    missing subroutine :" ;

    $MS{"EmbeddedFiles"}           = "        embedded files :" ;
    $MS{"BeginEndError"}           = "          b/e error in :" ;
    $MS{"SynonymEntries"}          = "       synonym entries :" ;
    $MS{"SynonymErrors"}           = "           bad entries :" ;
    $MS{"RegisterEntries"}         = "      register entries :" ;
    $MS{"RegisterErrors"}          = "           bad entries :" ;
    $MS{"PassedCommands"}          = "       passed commands :" ;

    $MS{"NOfDocuments"}            = "       document blocks :" ;
    $MS{"NOfDefinitions"}          = "     definition blocks :" ;
    $MS{"NOfSkips"}                = "        skipped blocks :" ;
    $MS{"NOfSetups"}               = "         copied setups :" ;
    $MS{"NOfTemplates"}            = "      copied templates :" ;
    $MS{"NOfInfos"}                = "      copied helpinfos :" ;
    $MS{"NOfFigures"}              = "     processed figures :" ;
    $MS{"NOfBoxes"}                = "        overfull boxes :" ;
    $MS{"NOfUnknown"}              = "           unknown ... :" ;

    $MS{"InputFile"}               = "            input file :" ;
    $MS{"OutputFile"}              = "           output file :" ;
    $MS{"FileType"}                = "             file type :" ;
    $MS{"EpsFile"}                 = "              eps file :" ;
    $MS{"TifFile"}                 = "              tif file :" ;
    $MS{"MPFile"}                  = "         metapost file :" ;

    $MS{"Overfull"}                = "overfull" ;
    $MS{"Entries"}                 = "entries" ;
    $MS{"References"}              = "references" ;

  } # end of english section

#D \stopcompressdefinitions

#D Showing the banner (name and version of the program) and
#D offering helpinfo is rather straightforward.

sub ShowBanner
  { Report("\n$Program\n") }

sub ShowHelpInfo
  { Report("HelpInfo") }

#D The helpinfo is also saved in the hash table. This looks
#D like a waste of energy and space, but the program gains
#D readability.

#D \startcompressdefinitions

if ($Interface eq "nl")

  { # begin of dutch section

    $MS{"HelpInfo"} =

    "          --references   hulp file verwerken / tui->tuo                 \n" .
    "                       --ij : IJ als Y sorteren                         \n" .
    "                       --high : hoge ASCII waarden converteren          \n" .
    "                       --quotes : quotes converteren                    \n" .
    "                                                                        \n" .
    "           --documents   documentatie file genereren / tex->ted         \n" .
    "             --sources   broncode file genereren / tex->tes             \n" .
    "              --setups   ConTeXt definities filteren / tex->texutil.tus \n".
    "           --templates   TeXEdit templates filteren / tex->tud          \n" .
    "               --infos   TeXEdit helpinfo filteren / tex->tud           \n" .
    "                                                                        \n" .
    "             --figures   eps figuren lijst genereren / eps->texutil.tuf \n".
    "                       --tiff : ook tif files verwerken                 \n" .
    "                                                                        \n" .
    "             --logfile   logfile filteren / log->texutil.log            \n" .
    "                       --box : overfull boxes controleren               \n" .
    "                       --criterium : overfull criterium in pt           \n" .
    "                       --unknown :onbekende ... controleren             \n" ;

  } # end of dutch section

elsif ($Interface eq "de")

  { # begin of german section

    $MS{"HelpInfo"} =

    "          --references   Verarbeiten der Hilfsdatei / tui->tuo          \n" .
    "                       --ij : Sortiere IJ als Y                         \n" .
    "                       --high : Konvertiere hohe ASCII-Werte            \n" .
    "                       --quotes : Konvertiere akzentuierte Buchstaben   \n" .
    "                                                                        \n" .
    "           --documents   Erstelle Dokumentationsdatei / tex->ted        \n" .
    "             --sources   Erstelle reine Quelltextdateien / tex->tes     \n" .
    "              --setups   Filtere ConTeXt-Definitionen / tex->texutil.tus\n" .
    "           --templates   Filtere TeXEdit-templates / tex->tud           \n" .
    "               --infos   Filtere TeXEdit-helpinfo / tex->tud            \n" .
    "                                                                        \n" .
    "             --figures   Erstelle eps-Abbildungsliste / eps->texutil.tuf\n" .
    "                       --tiff : Verarbeite auch tif-Dateien             \n" .
    "                                                                        \n" .
    "             --logfile   Filtere log-Datei / log->texutil.log           \n" .
    "                       --box : Ueberpruefe uebervolle Boxen             \n" .
    "                       --criterium : Uebervoll-Kriterium in pt          \n" .
    "                       --unknown : Ueberpruefe auf unbekannte ...       \n" ;

  } # end of german section


else

  { # begin of english section

    $MS{"HelpInfo"} =

    "          --references   process auxiliary file / tui->tuo             \n" .
    "                       --ij : sort IJ as Y                             \n" .
    "                       --high : convert high ASCII values              \n" .
    "                       --quotes : convert quotes characters            \n" .
    "                                                                       \n" .
    "           --documents   generate documentation file / tex->ted        \n" .
    "             --sources   generate source only file / tex->tes          \n" .
    "              --setups   filter ConTeXt definitions / tex->texutil.tus \n" .
    "           --templates   filter TeXEdit templates / tex->tud           \n" .
    "               --infos   filter TeXEdit helpinfo / tex->tud            \n" .
    "                                                                       \n" .
    "             --figures   generate eps figure list / eps->texutil.tuf   \n" .
    "                       --tiff : also process tif files                 \n" .
    "                                                                       \n" .
    "             --logfile   filter logfile / log->texutil.log             \n" .
    "                       --box : check overful boxes                     \n" .
    "                       --criterium : overfull criterium in pt          \n" .
    "                       --unknown : check unknown ...                   \n" ;

  } # end of english section

#D \stopcompressdefinitions

#D In order to sort strings correctly, we have to sanitize
#D them. This is especially needed when we include \TEX\
#D commands, quotes characters and compound word placeholders.
#D
#D \startopsomming[opelkaar]
#D \som  \type{\name}: csnames are stripped
#D \som  \type{{}}: are removed
#D \som  \type{\"e}: and alike are translated into \type{"e} etc.
#D \som  \type{"e}: is translated into an \type{e} and \type{b} etc.
#D \som  \type{||}: becomes \type{-}
#D \som  \type{\-}: also becomes \type{-}
#D \stopopsomming
#D
#D Of course other accented characters are handled too. The
#D appended string is responsible for decent sorting.
#D
#D \startPL
#D $TargetString = SanitizedString ( $SourceString ) ;
#D \stopPL
#D
#D The sort order depends on the ordering in array
#D \type{$ASCII}:

$ASCII{"^"} = "a" ;  $ASCII{'"'} = "b" ;  $ASCII{"`"} = "c" ;
$ASCII{"'"} = "d" ;  $ASCII{"~"} = "e" ;  $ASCII{","} = "f" ;

sub SanitizedString
  { my ($string) = $_[0] ;
    if ($ProcessQuotes)
      { $string =~ s/\\([\^\"\`\'\~\,])/$1/gio ;
        $copied = $string ;
        $copied =~ s/([\^\"\`\'\~\,])([a-zA-Z])/$ASCII{$1}/gio ;
        $string =~ s/([\^\"\`\'\~\,])([a-zA-Z])/$2/gio ;
        $string=$string.$copied }
    $string =~ s/\\-|\|\|/\-/gio ;
    $string =~ s/\\[a-zA-Z]*| |\{|\}//gio ;
    return $string }

#D This subroutine looks a bit complicated, which is due to the
#D fact that we want to sort for instance an accented \type{e}
#D after the plain \type{e}, so the imaginary words
#D
#D \starttypen
#D eerste
#D \"eerste
#D \"e\"erste
#D eerst\"e
#D \stoptypen
#D
#D come out in an acceptable order.

#D We also have to deal with the typical \TEX\ sequences with
#D the double \type{^}'s, like \type{^^45}. These hexadecimal
#D coded characters are just converted.
#D
#D \startPL
#D $TargetString = HighConverted ( $SourceString ) ;
#D \stopPL

sub HighConverted
  { my ($string) = $_[0] ;
    $string =~ s/\^\^([a-f0-9][a-f0-9])/chr hex($1)/geo ;
    return $string }

#D \extras
#D   {references}
#D
#D \CONTEXT\ can handle many lists, registers (indexes),
#D tables of whatever and references. This data is collected
#D in one pass and processed in a second one. In between,
#D relevant data is saved in the file \type{\jobname.tui}.
#D This file also holds some additional information concerning
#D second pass optimizations.
#D
#D The main task of \TEXUTIL\ is to sort lists and registers
#D (indexes). The results are stored in again one file called
#D \type{\jobname.tuo}.
#D
#D Just for debugging purposes the nesting of files loaded
#D during the \CONTEXT\ run is stored. Of course this only
#D applies to files that are handled by the \CONTEXT\ file
#D structuring commands (projects, products, components and
#D environments).
#D
#D We have to handle the entries:
#D
#D \starttypen
#D f b {test}
#D f e {test}
#D \stoptypen
#D
#D and only report some status info at the end of the run.

sub InitializeFiles
  { $NOfFiles = 0 ;
    $NOfBadFiles = 0 }

sub HandleFile
 { $RestOfLine =~ s/.*\{(.*)\}/$1/gio ;
   ++$Files{$RestOfLine} }

sub FlushFiles
  { print TUO "%\n" . "% Files\n" . "%\n" ;
    foreach $File (keys %Files)
      { print TUO "% $File ($Files{$File})\n" }
    print TUO "%\n" ;
    $NOfFiles = keys %Files ;
    Report("EmbeddedFiles", $NOfFiles) ;
    foreach $File (keys %Files)
      { unless (($Files{$File} % 2) eq 0)
          { ++$NOfBadFiles ;
            Report("BeginEndError", $File) } } }

#D Commands don't need a special treatment. They are just
#D copied. Such commands are tagged by a \type{c}, like:
#D
#D \starttypen
#D c \thisisutilityversion{year.month.day}
#D c \twopassentry{class}{key}{value}
#D c \mainreference{prefix}{entry}{pagenumber}{realpage}{tag}
#D c \listentry{category}{tag}{number}{title}{pagenumber}{realpage}
#D c \realnumberofpages{number}
#D \stoptypen
#D
#D For historic reasons we check for the presense of the
#D backslash.

sub InitializeCommands
  { print TUO "%\n" . "% Commands\n" . "%\n" ;
    $NOfCommands = 0 }

sub HandleCommand
  { ++$NOfCommands ;
    $RestOfLine =~ s/^\\//go ;
    print TUO  "\\$RestOfLine\n" }

sub FlushCommands
  { Report ("PassedCommands", $NOfCommands) }

#D Synonyms are a sort of key||value pairs and are used for
#D ordered lists like abbreviations and units.
#D
#D \starttypen
#D s e {class}{sanitized key}{key}{associated data}
#D \stoptypen
#D
#D The sorted lists are saved as (surprise):
#D
#D \starttypen
#D \synonymentry{class}{sanitized key}{key}{associated data}
#D \stoptypen

sub InitializeSynonyms
  { $NOfSynonyms = 0 ;
    $NOfBadSynonyms = 0 }

#M \definieersynoniem [testname] [testnames] [\testmeaning]
#M
#M \stelsynoniemenin [testname] [criterium=alles]

#D Let's first make clear what we can expect. Synonym
#D entries look like:
#D
#D \startbuffer
#D \testname [alpha] {\sl alpha}  {a greek letter a}
#D \testname {alpha}              {another a}
#D \testname [Beta]  {\kap{beta}} {a greek letter b}
#D \testname {beta}               {indeed another b}
#D \testname {gamma}              {something alike g}
#D \testname {delta}              {just a greek d}
#D \stopbuffer
#D
#D \typebuffer
#D
#D This not that spectacular list is to be sorted according
#D to the keys (names). \haalbuffer

sub HandleSynonym
  { ++$NOfSynonyms ;
    ($SecondTag, $RestOfLine) = split(/ /, $RestOfLine, 2) ;
    ($Class, $Key, $Entry, $Meaning) = split(/} \{/, $RestOfLine) ;
    chop $Meaning ;
    $Class = substr $Class, 1 ;
    if ($Entry eq "")
      { ++$NOfBadSynonyms }
    else
      { $SynonymEntry[$NOfSynonyms] =
          $Class . $JOIN .
          $Key   . $JOIN .
          $Entry . $JOIN .
          $Meaning ;
                $SynonymEntry[$NOfSynonyms+1] = "" ; } }

#D Depending on the settings\voetnoot{One can call for
#D all defined entries, call only the used ones, change
#D layout, attach (funny) commands etc.} a list of
#D {\em testnames} looks like:
#D
#D \plaatslijstmettestnames
#D
#D Watch the order in which these entries are sorted.

$SynonymEntry[0] = ("") ; # TH: initalize 

sub FlushSynonyms
  { print TUO "%\n" . "% Synonyms\n" . "%\n" ;
    @SynonymEntry = sort @SynonymEntry ;
    $NOfSaneSynonyms = 0 ;
    for ($n=1; $n<=$NOfSynonyms; ++$n)
      { # check normally not needed
        if ($SynonymEntry[$n] ne $SynonymEntry[$n-1])  
          { ($Class, $Key, $Entry, $Meaning) =
               split(/$JOIN/, $SynonymEntry[$n]) ;
            ++$NOfSaneSynonyms ;
            print TUO "\\synonymentry{$Class}{$Key}{$Entry}{$Meaning}\n" } }
    Report("SynonymEntries", $NOfSynonyms, "->", $NOfSaneSynonyms, "Entries") ;
    if ($NOfBadSynonyms>0)
      { Report("SynonymErrors", $NOfBadSynonyms) } }

#D Register entries need a bit more care, especially when they
#D are nested. In the near future we will also handle page
#D ranges.
#D
#D \starttypen
#D r e {class}{tag}{sanitized key}{key}{pagenumber}{realpage}
#D r s {class}{tag}{sanitized key}{key}{string}{pagenumber}
#D \stoptypen

#D The first one is the normal entry, the second one concerns
#D {\em see this or that} entries. Keys are sanitized, unless
#D the user supplies a sanitized key. To save a lot of
#D programming, all data concerning an entry is stored in one
#D string. Subentries are specified as:
#D
#D \starttypen
#D first&second&third
#D first+second+third
#D \stoptypen
#D
#D When these characters are needed for typesetting purposes, we
#D can also use the first character to specify the separator:
#D
#D \starttypen
#D &$x^2+y^2=r^2$
#D +this \& that
#D \stoptypen
#D
#D Subentries are first unpacked and next stored in a
#D consistent way, which means that we can use both separators
#D alongside each other. We leave it to the reader to sort
#D out the dirty tricks.

$SPLIT ="%%" ;
$JOIN ="__" ;

sub InitializeRegisters
  { $NOfEntries = 0 ;
    $NOfBadEntries = 0 }

$ProcessType = "" ; # TH: initialize 

sub HandleRegister
  { ($SecondTag, $RestOfLine) = split(/ /, $RestOfLine, 2) ;
    ++$NOfEntries ;
    if ($SecondTag eq "s")
      { ($Class, $Location, $Key, $Entry, $SeeToo, $Page ) =
           split(/} \{/, $RestOfLine) ;
        chop $Page ;
        $Class = substr $Class, 1 ;
        $RealPage = 0 }
    else
      { ($Class, $Location, $Key, $Entry, $Page, $RealPage ) =
           split(/} \{/, $RestOfLine) ;
        chop $RealPage ;
        $Class = substr $Class, 1 ;
        $SeeToo = "" }
    if ($Key eq "")
      { $Key = SanitizedString($Entry) }
    if ($ProcessHigh)
      { $Key = HighConverted($Key) }
    $KeyTag = substr $Key, 0, 1 ;
    if ($KeyTag eq "&")
      { $Key   =~ s/^\&//go ;
        $Key   =~ s/([^\\])\&/$1$SPLIT/go }
    elsif ($KeyTag eq "+")
      { $Key   =~ s/^\+//go ;
        $Key   =~ s/([^\\])\+/$1$SPLIT/go }
    else
      { $Key   =~ s/([^\\])\&/$1$SPLIT/go ;
        $Key   =~ s/([^\\])\+/$1$SPLIT/go }
    $EntryTag = substr $Entry, 0, 1 ;
    if ($EntryTag eq "&")
      { $Entry =~ s/^\&//go ;
        $Entry =~ s/([^\\])\&/$1$SPLIT/go }
    elsif ($EntryTag eq "+")
      { $Entry =~ s/^\+//go ;
        $Entry =~ s/([^\\])\+/$1$SPLIT/go }
    else
      { $Entry =~ s/([^\\])\&/$1$SPLIT/go ;
        $Entry =~ s/([^\\])\+/$1$SPLIT/go }
    $Key =~ s/^([^a-zA-Z])/ $1/go ;    
    if ($ProcessIJ)
      { $Key =~ s/ij/yy/go }
    $LCKey = lc $Key ;
    $RegisterEntry[$NOfEntries] =
      $Class    . $JOIN .
      $LCKey    . $JOIN .
      $Key      . $JOIN .
      $Entry    . $JOIN .
      $RealPage . $JOIN .
      $Location . $JOIN .
      $Page     . $JOIN .
      $SeeToo }

#M \definieerregister [testentry] [testentries]

#D The previous routine deals with entries like:
#D
#D \startbuffer
#D \testentry {alpha}
#D \testentry {beta}
#D \testentry {gamma}
#D \testentry {gamma}
#D \testentry {delta}
#D \testentry {epsilon}
#D \testentry {alpha+first}
#D \testentry {alpha+second}
#D \testentry {alpha+second}
#D \testentry {alpha+third}
#D \testentry {alpha+second+one}
#D \testentry {alpha+second+one}
#D \testentry {alpha+second+two}
#D \testentry {alpha+second+three}
#D \testentry {gamma+first+one}
#D \testentry {gamma+second}
#D \testentry {gamma+second+one}
#D
#D \testentry {alpha+fourth}
#D \testentry {&alpha&fourth}
#D \testentry {+alpha+fourth}
#D
#D \testentry [alpha+fourth]      {alpha+fourth}
#D \testentry [&alpha&fourth&one] {&alpha&fourth&one}
#D \testentry [+alpha+fourth+two] {&alpha&fourth&two}
#D
#D \testentry {\kap{alpha}+fifth}
#D \testentry {\kap{alpha}+f\'ifth}
#D \testentry {\kap{alpha}+f"ifth}
#D
#D \testentry [&betaformula] {&$a^2+b^2=c^2$}
#D
#D \testentry {zeta \& more}
#D \stopbuffer
#D
#D \typebuffer
#D
#D \haalbuffer After being sorted, these entries are
#D turned into something \TEX\ using:

$RegisterEntry[0] = ("") ; # TH: initialize 

sub FlushRegisters
  { print TUO "%\n" . "% Registers\n" . "%\n" ;
    @RegisterEntry  = sort @RegisterEntry ;
    $NOfSaneEntries = 0 ;
    $NOfSanePages   = 0 ;
    $LastPage       = "" ;
    $LastRealPage   = "" ;
    $AlfaClass      = "" ;
    $Alfa           = "" ;
    $PreviousA      = "" ;
    $PreviousB      = "" ;
    $PreviousC      = "" ;
    $ActualA        = "" ;
    $ActualB        = "" ;
    $ActualC        = "" ;
    for ($n=1 ; $n<=$NOfEntries ; ++$n)
      { ($Class, $LCKey, $Key, $Entry, $RealPage, $Location, $Page, $SeeToo) =
           split(/$JOIN/, $RegisterEntry[$n]) ;
        if (((lc substr $Key, 0, 1) ne lc $Alfa) or ($AlfaClass ne $Class))
          { $Alfa= lc substr $Key, 0, 1 ;
            $AlfaClass = $Class ;
            if ($Alfa ne " ")
              { print TUO "\\registerentry{$Class}{$Alfa}\n" } }
        ($ActualA, $ActualB, $ActualC ) =
           split(/$SPLIT/, $Entry, 3) ;
        unless ($ActualA) { $ActualA = "" } # TH: this would be an error
        unless ($ActualB) { $ActualB = "" } # TH: might become undef through split()
        unless ($ActualC) { $ActualC = "" } # TH: might become undef through split()
        if ($ActualA eq $PreviousA)
          { $ActualA = "" }
        else
          { $PreviousA = $ActualA ;
            $PreviousB = "" ;
            $PreviousC = "" }
        if ($ActualB eq $PreviousB)
          { $ActualB = "" }
        else
          { $PreviousB = $ActualB ;
            $PreviousC = "" }
        if ($ActualC eq $PreviousC)
          { $ActualC = "" }
        else
          { $PreviousC = $ActualC }
        $Copied = 0 ;
        if ($ActualA ne "")
           { print TUO "\\registerentrya{$Class}{$ActualA}\n" ;
             $Copied = 1 }
        if ($ActualB ne "")
           { print TUO "\\registerentryb{$Class}{$ActualB}\n" ;
             $Copied = 1 }
        if ($ActualC ne "")
           { print TUO "\\registerentryc{$Class}{$ActualC}\n" ;
             $Copied = 1 }
        if ($Copied)
          { $NOfSaneEntries++ }
        if ($RealPage eq 0)
          { print TUO "\\registersee{$Class}{$SeeToo}{$Page}\n" ;
            $LastPage = $Page ;
            $LastRealPage = $RealPage }
        elsif (($Copied) ||
              ! (($LastPage eq $Page) and ($LastRealPage eq $RealPage)))
          { print TUO "\\registerpage{$Class}{$Location}{$Page}{$RealPage}\n" ;
            ++$NOfSanePages ;
            $LastPage = $Page ;
            $LastRealPage = $RealPage } }
    Report("RegisterEntries", $NOfEntries, "->", $NOfSaneEntries, "Entries",
                                                 $NOfSanePages,   "References") ;
    if ($NOfBadEntries>0)
      { Report("RegisterErrors", $NOfBadEntries) } }

#D As promised, we show the results:
#D
#D \plaatstestentry

#D For debugging purposes we flush some status information. The
#D faster machines become, the more important this section will
#D be.

sub FlushData
  { print TUO
      "% This Session\n" .
      "% \n" .
      "% embedded files   : $NOfFiles ($NOfBadFiles errors)\n" .
      "% passed commands  : $NOfCommands\n" .
      "% synonym entries  : $NOfSynonyms ($NOfBadSynonyms errors)\n" .
      "% register entries : $NOfEntries ($NOfBadEntries errors)" }

#D The functionallity described on the previous few pages is
#D called upon in the main routine:

sub HandleReferences
  { Report("Action", "ProcessingReferences") ;
    if ($ProcessIJ  )
      { Report("Option", "SortingIJ") }
    if ($ProcessHigh)
      { Report("Option", "ConvertingHigh") }
    if ($ProcessQuotes)
      { Report("Option", "ProcessingQuotes") }
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { unless (open (TUI, "$InputFile.tui"))
          { Report("Error", "EmptyInputFile", $InputFile) }
        else
          { Report("InputFile", "$InputFile.tui" ) ;
            InitializeCommands ;
            InitializeRegisters ;
            InitializeSynonyms ;
            InitializeFiles ;
            $ValidOutput = 1 ;
            unlink "$InputFile.tmp" ; 
            rename "$InputFile.tuo", "$InputFile.tmp" ; 
            Report("OutputFile", "$InputFile.tuo" ) ;
            open (TUO, ">$InputFile.tuo") ;
            while ($SomeLine=<TUI>)
              { chop $SomeLine ; 
                ($FirstTag, $RestOfLine) = split ' ', $SomeLine, 2 ;
                if    ($FirstTag eq "c")
                  { HandleCommand }
                elsif ($FirstTag eq "s")
                  { HandleSynonym }
                elsif ($FirstTag eq "r")
                  { HandleRegister }
                elsif ($FirstTag eq "f")
                  { HandleFile } 
                elsif ($FirstTag eq "q")
                  { $ValidOutput = 0 ; 
                    last } }
            if ($ValidOutput) 
             { FlushCommands ; # already done during pass
               FlushRegisters ;
               FlushSynonyms ;
               FlushFiles ;
               FlushData } 
            else
             { unlink "$InputFile.tuo" ;
               rename "$InputFile.tmp", "$InputFile.tuo" ; 
               Report ("Error", "NoOutputFile") } } } }

#D \extras
#D   {documents}
#D
#D Documentation can be woven into a source file. The next
#D routine generates a new, \TEX\ ready file with the
#D documentation and source fragments properly tagged. The
#D documentation is included as comment:
#D
#D \starttypen
#D %D ......  some kind of documentation
#D %M ......  macros needed for documenation
#D %S B       begin skipping
#D %S E       end skipping
#D \stoptypen
#D
#D The most important tag is \type{%D}. Both \TEX\ and
#D \METAPOST\ files use \type{%} as a comment chacacter, while
#D \PERL\ uses \type{#}. Therefore \type{#D} is also handled.
#D
#D The generated file gets the suffix \type{ted} and is
#D structured as:
#D
#D \starttypen
#D \startmodule[type=suffix]
#D \startdocumentation
#D \stopdocumentation
#D \startdefinition
#D \stopdefinition
#D \stopmodule
#D \stoptypen
#D
#D Macro definitions specific to the documentation are not
#D surrounded by start||stop commands. The suffix specifaction
#D can be overruled at runtime, but defaults to the file
#D extension. This specification can be used for language
#D depended verbatim typesetting.
    
sub HandleDocuments
  { Report("Action", "HandlingDocuments") ;
    if ($ProcessType ne "")
      { Report("Option", "ForcingFileType", $ProcessType) }
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = split (/\./, $FullName, 2) ;
            unless ($FileSuffix)
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
                        else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                Report("OutputFile", "$FileName.ted") ;
                open (TED, ">$FileName.ted") ;
                $NOfDocuments   = 0 ;
                $NOfDefinitions = 0 ;
                $NOfSkips       = 0 ;
                $SkipLevel      = 0 ;
                $InDocument     = 0 ;
                $InDefinition   = 0 ;
                if ($ProcessType eq "")
                  { $FileType=lc $FileSuffix }
                else
                  { $FileType=lc $ProcessType }
                Report("FileType", $FileType) ;
                print TED "\\startmodule[type=$FileType]\n" ;
                while (<TEX>) # TH: $SomeLines replaced by $_
                  { chop;
                    if (/^[%\#]D/)
                      { if ($SkipLevel == 0)
                          { if (length $_ < 3)  # TH: empty #D comment
                              {$SomeLine = "" } 
                            else                # HH: added after that
                              {$SomeLine = substr ($_, 3) } 
                            if ($InDocument)
                              { print TED "$SomeLine\n" }
                            else
                              { if ($InDefinition)
                                  { print TED "\\stopdefinition\n" ;
                                    $InDefinition = 0 }
                                unless ($InDocument)
                                  { print TED "\n\\startdocumentation\n" }
                                print TED "$SomeLine\n" ;
                                $InDocument = 1 ;
                                ++$NOfDocuments } } }
                    elsif (/^[%\#]M/)
                      { if ($SkipLevel == 0)
                          { $SomeLine = substr $_, 3 ;
                            print TED "$SomeLine\n" } }
                   elsif (/^[%\%]S B]/)
                     { ++$SkipLevel ;
                       ++$NOfSkips }
                   elsif (/^[%\%]S E]/)
                     { --$SkipLevel }
                    elsif (/^[%\#]/)
                     { }
                    elsif ($SkipLevel == 0)
                      { $InLocalDocument = $InDocument ;
                        $SomeLine = $_ ;
                        if ($InDocument)
                          { print TED "\\stopdocumentation\n" ;
                            $InDocument = 0 }
                        if (($SomeLine eq "") && ($InDefinition))
                          { print TED "\\stopdefinition\n" ;
                            $InDefinition = 0 }
                        else
                          { if ($InDefinition)
                              { print TED "$SomeLine\n" }
                            elsif ($SomeLine ne "")
                              { print TED "\n" . "\\startdefinition\n" ;
                                $InDefinition = 1 ;
                                unless ($InLocalDocument)
                                  { ++$NOfDefinitions }
                                print TED "$SomeLine\n" } } } }
                if ($InDocument)
                  { print TED "\\stopdocumentation\n" }
                if ($InDefinition)
                  { print TED "\\stopdefinition\n" }
                print TED "\\stopmodule\n" ;
                close (TED) ;
                unless (($NOfDocuments) || ($NOfDefinitions))
                  { unlink "$FileName.ted" }
                Report ("NOfDocuments", $NOfDocuments) ;
                Report ("NOfDefinitions", $NOfDefinitions) ;
                Report ("NOfSkips", $NOfSkips) } } } }

#D \extras
#D   {sources}
#D
#D Documented sources can be stripped of documentation and
#D comments, although at the current processing speeds the
#D overhead of skipping the documentation at run time is
#D neglectable. Only lines beginning with a \type{%} are
#D stripped. The stripped files gets the suffix \type{tes}.

sub HandleSources
  { Report("Action", "GeneratingSources") ;
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = split (/\./, $FullName, 2) ;
            unless ($FileSuffix)
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                Report("OutputFile", "$FileName.tes") ;
                open (TES, ">$FileName.tes") ;
                $EmptyLineDone = 1 ;
                $FirstCommentDone = 0 ;
                while ($SomeLine=<TEX>)
                  { chop $SomeLine ; 
                    if ($SomeLine eq "")
                      { unless ($FirstCommentDone)
                          { $FirstCommentDone = 1 ;
                            print TES
                              "\n% further documentation is removed\n\n" ;
                            $EmptyLineDone = 1 }
                        unless ($EmptyLineDone)
                          { print TES "\n" ;
                            $EmptyLineDone = 1 } }
                    elsif ($SomeLine =~ /^%/)
                      { unless ($FirstCommentDone)
                          { print TES "$SomeLine\n" ;
                            $EmptyLineDone = 0 } }
                    else
                      { print TES "$SomeLine\n" ;
                        $EmptyLineDone = 0 } } 
                close (TES) ; # TH: repaired                
                unless ($FirstCommentDone)
                  { unlink "$FileName.tes" } } } } }

#D \extras
#D   {setups}
#D
#D All \CONTEXT\ commands are specified in a compact format
#D that can be used to generate quick reference tables and
#D cards. Such setups are preceded by \type{%S}. The setups
#D are collected in the file \type{texutil.tus}.

sub HandleSetups
  { Report("Action", "FilteringDefinitions" ) ;
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { Report("OutputFile", "texutil.tus") ;
        open (TUS, ">texutil.tus") ; # this file is always reset!
        $NOfSetups = 0 ;
        CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = split (/\./, $FullName, 2) ;
            unless ($FileSuffix)
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                print TUS "%\n" . "% File : $FileName.$FileSuffix\n" . "%\n" ;
                while ($SomeLine=<TEX>)
                  { chomp ;
                    chop $SomeLine ;
                    ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) ;
                    if ($Tag eq "%S")
                      { ++$NOfSetups ;
                        while ($Tag eq "%S")
                          { print TUS "$RestOfLine\n" ;
                            $SomeLine = <TEX> ;
                            chomp ;
                            chop $SomeLine ;
                            ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) }
                        print TUS "\n" } } } }
        close (TUS) ;
        unless ($NOfSetups)
          { unlink "texutil.tus" }
        Report("NOfSetups", $NOfSetups) } }

#D \extras
#D   {templates, infos}
#D
#D From the beginning, the \CONTEXT\ source files contained
#D helpinfo and key||templates for \TEXEDIT. In fact, for a
#D long time, this was the only documentation present. More
#D and more typeset (interactive) documentation is replacing
#D this helpinfo, but we still support the traditional method.
#D This information is formatted like:
#D
#D \starttypen
#D %I n=Struts
#D %I c=\strut,\setnostrut,\setstrut,\toonstruts
#D %I
#D %I text
#D %I ....
#D %P
#D %I text
#D %I ....
#D \stoptypen
#D
#D Templates look like:
#D
#D \starttypen
#D %T n=kap
#D %T m=kap
#D %T a=k
#D %T
#D %T \kap{?}
#D \stoptypen
#D
#D The key||value pairs stand for {\em name}, {\em mnemonic},
#D {\em key}. This information is copied to files with the
#D extension \type{tud}.

sub HandleEditorCues
  { if ($ProcessTemplates)
      { Report("Action", "CopyingTemplates" ) }
    if ($ProcessInfos)
      {Report("Action", "CopyingInformation" ) }
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = split (/\./, $FullName, 2) ;
            if ($FileSuffix eq "")
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                Report("OutputFile", "$FileName.tud") ;
                open (TUD, ">$FileName.tud") ;
                $NOfTemplates = 0 ;
                $NOfInfos = 0 ;
                while ($SomeLine=<TEX>)
                  { chomp ;
                    chop $SomeLine ;
                    ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) ;
                    if (($Tag eq "%T") && ($ProcessTemplates))
                      { ++$NOfTemplates ;
                       while ($Tag eq "%T")
                         { print TUD "$SomeLine\n" ;
                           $SomeLine = <TEX> ;
                           chomp ;
                           chop $SomeLine ;
                           ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) }
                           print TUD "\n" }
                    elsif (($Tag eq "%I") && ($ProcessInfos))
                      { ++$NOfInfos ;
                        while (($Tag eq "%I") || ($Tag eq "%P"))
                          { print TUD "$SomeLine\n" ;
                            $SomeLine = <TEX> ;
                            chomp ;
                            chop $SomeLine ;
                            ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) }
                            print TUD "\n" } }
                close (TUD) ;
                unless (($NOfTemplates) || ($NOfInfos))
                  { unlink "$FileName.tud" }
                if ($ProcessTemplates)
                  { Report("NOfTemplates", $NOfTemplates) }
                if ($ProcessInfos)
                  { Report("NOfInfos", $NOfInfos) } } } } }

#D \extras
#D   {figures}
#D
#D Directories can be scanned for illustrations in \EPS\ or
#D \TIFF\ format. The later type of graphics is prescanned by
#D dedicated programs, whose data is used here. The resulting
#D file \type{texutil.tuf} contains entries like:
#D
#D \starttypen
#D \thisisfigureversion{year.month.day}
#D \presetfigure[file][...specifications...]
#D \stoptypen
#D
#D where the specifications are:
#D
#D \starttypen
#D [e=suffix,x=xoffset,y=yoffset,w=width,h=height,t=title,c=creator,s=size]
#D \stoptypen
#D
#D This data can be used when determining dimensions (although
#D \CONTEXT\ is able to scan \EPS\ illustrations directly) and
#D to generate directories of illustrations.

$PTtoCM = 2.54/72.0 ;
$INtoCM = 2.54 ;

sub HandleEpsFigure
  { my ( $SuppliedFileName ) = @_ ;
    ($FileName, $FileSuffix) = split ( /\./, $SuppliedFileName, 2) ;
    $Temp = $FileSuffix;
    $Temp =~ s/[0-9]//go;
    if ($Temp eq "")
      { $EpsFileName = $SuppliedFileName;
        Report ( "MPFile", "$SuppliedFileName" ) }
    elsif (lc $FileSuffix ne "eps")
      { return }
    else
      { $EpsFileName = $FileName;
        Report ( "EpsFile", "$SuppliedFileName" ) }
    $HiResBBOX = "" ;
    $LoResBBOX  = "" ;
    $EpsTitle = "" ;
    $EpsCreator = "" ;
    open ( EPS , $SuppliedFileName ) ;
    $EpsSize = -s EPS ;
    while ( $SomeLine = <EPS> )
      { chop ($SomeLine) ;
        unless ($HiResBBOX)
          { if ($SomeLine =~ /^%%BoundingBox:/i)
              { ($Tag, $LoResBBOX) = split (/ /, $SomeLine, 2) ;
                next }
            elsif ($SomeLine =~ /^%%HiResBoundingBox:/i)
              { ($Tag, $HiResBBOX) = split (/ /, $SomeLine, 2) ;
                next }
            elsif ($SomeLine =~ /^%%ExactBoundingBox:/i)
              { ($Tag, $HiResBBOX) = split (/ /, $SomeLine, 2) ;
                next } }
        if ($SomeLine =~ /^%%Creator:/i)
          { ($Tag, $EpsCreator) = split (/ /, $SomeLine, 2) }
        elsif ($SomeLine =~ /^%%Title:/i)
          { ($Tag, $EpsTitle) = split (/ /, $SomeLine, 2) } }
    if ($HiResBBOX)
      { $EpsBBOX = $HiResBBOX }
    else
      { $EpsBBOX = $LoResBBOX }
    if ($EpsBBOX)
      { ($LLX, $LLY, $URX, $URY, $RestOfLine) = split (/ /, $EpsBBOX, 5 ) ;
        $EpsHeight  = ($URY-$LLY)*$PTtoCM ;
        $EpsWidth   = ($URX-$LLX)*$PTtoCM ;
        $EpsXOffset = $LLX*$PTtoCM ;
        $EpsYOffset = $LLY*$PTtoCM ;
        $Figures[++$NOfFigures] =
          "\\presetfigure[$EpsFileName][e=eps" .
          (sprintf  ",x=%5.3fcm,y=%5.3fcm", $EpsXOffset, $EpsYOffset)  .
          (sprintf  ",w=%5.3fcm,h=%5.3fcm", $EpsWidth,   $EpsHeight)  .
          ",t=$EpsTitle,c=$EpsCreator,s=$EpsSize]\n" } }

sub HandleEpsFigures
  { if ($InputFile eq "")
      { $InputFile = "*.eps" }
    CheckInputFiles ($InputFile) ;
    foreach $FileName (@UserSuppliedFiles)
      { HandleEpsFigure ( $FileName ) } }

#D Here we call the programs that generate information on
#D the \TIFF\ files. The names of the programs are defined
#D earlier.

if ($ProcessTiff)
  { $FindTiffFigure = "" ;
    $UsedTiffProgram = "" ;
    unlink "tiffdata.tmp" ;
    foreach $TiffProgram (@TiffPrograms)
      { if ((system ("$TiffProgram *.tif > tiffdata.tmp") == 0)
            && (-s "tiffdata.tmp"))
          { $UsedTiffProgram = $TiffProgram ;
            $FindTiffFigure = "FindTiffFigure_$UsedTiffProgram" ;
            last } } }

#D The scanning routines use filehandle \type{TMP} and call for
#D \type{ReportTifFigure} with the arguments \type{Name},
#D \type{Width} and \type{Height}.

sub ReportTifFigure
  { my ($Name, $Width, $Height) = @_ ;
    $Name = lc $Name ;
    #
    # if ($InputFile ne "")
    #   { $Ok = 0 ;
    #     foreach $IFile (@UserSuppliedFiles)
    #     { $Ok = ($Ok || ($IFile eq "$Name.tif" )) }
    # else
    #   { $Ok = 1 }
    #
    $Ok = 1 ;
    #
    if ($Ok)
      { $Size = -s "$Name.tif" ;
        Report ( "TifFile", "$Name.tif") ;
        $Figures[++$NOfFigures] =
          "\\presetfigure[$Name][e=tif" .
          (sprintf ",w=%5.3fcm,h=%5.3fcm", $Width, $Height) .
          ",s=$Size]\n" } }

sub HandleTifFigures
  { if ($ProcessTiff)
      { if (-s "tiffdata.tmp")
          { Report ( "SystemCall", "$UsedTiffProgram -> tiffdata.tmp" ) ;
           if ((defined &$FindTiffFigure) && (open(TMP, "tiffdata.tmp")))
              { &$FindTiffFigure }
           else
              { Report ( "MissingSubroutine", $FindTiffFigure ) } }
        else
          { Report ( "BadSystemCall", "@TiffPrograms" ) } } }

#D The next few routines are program specific. Let's cross our
#D fingers on the stability off their output.  As one can
#D see, we have to work a bit harder when we use \TIFFINFO\
#D instead of \TIFFTAGS.

sub FindTiffFigure_tiffinfo
  { while ( $TifName = <TMP> )
      { chomp ;
        chop $TifName ;
        if (($TifName =~ s/^(.*)\.tif\:.*/$1/i) &&
            ($SomeLineA = <TMP>) && ($SomeLineA = <TMP>) &&
            ($SomeLineA = <TMP>) && ($SomeLineB = <TMP>))
          { chop $SomeLineA ;
            $TifWidth  =  $SomeLineA ;
            $TifWidth  =~ s/.*Image Width: (.*) .*/$1/i ;
            $TifHeight =  $SomeLineA ;
            $TifHeight =~ s/.*Image Length: (.*).*/$1/i ;
            $TifWRes   =  $SomeLineB ;
            $TifWRes   =~ s/.*Resolution: (.*)\,.*/$1/i ;
            $TifHRes   =  $SomeLineB ;
            $TifHRes   =~ s/.*Resolution: .*\, (.*).*/$1/i ;
            $TifWidth  = ($TifWidth/$TifWRes)*$INtoCM ;
            $TifHeight = ($TifHeight/$TifHRes)*$INtoCM ;
            ReportTifFigure ($TifName, $TifWidth, $TifHeight) } } }

sub FindTiffFigure_tifftags
  { while ( $TifName = <TMP> )
      { chomp ;
        chop $TifName ;
        if (($TifName =~ s/.*\`(.*)\.tif\'.*/$1/i) &&
            ($SomeLine = <TMP>) && ($SomeLine = <TMP>))
          { chop $SomeLine ;
            $TifWidth  =  $SomeLine ;
            $TifWidth  =~ s/.*\((.*) pt.*\((.*) pt.*/$1/ ;
            $TifHeight =  $SomeLine ;
            $TifHeight =~ s/.*\((.*) pt.*\((.*) pt.*/$2/ ;
            $TifWidth  =  $TifWidth*$PTtoCM ;
            $TifHeight =  $TifHeight*$PTtoCM ;
            ReportTifFigure ($TifName, $TifWidth, $TifHeight) } } }

sub InitializeFigures
  { $NOfFigures = 0 }

sub FlushFigures
  { $Figures = sort $Figures ;
    open ( TUF, ">texutil.tuf" ) ;
    print TUF "%\n" . "% Figures\n" . "%\n" ;
    print TUF "\\thisisfigureversion\{1996.06.01\}\n" . "%\n" ;
    for ($n=1 ; $n<=$NOfFigures ; ++$n)
      { print TUF $Figures[$n] }
    close (TUF) ;
    unless ($NOfFigures)
     { unlink "texutil.tuf" }
    Report ( "NOfFigures", $NOfFigures ) }

sub HandleFigures
  { Report("Action",  "GeneratingFigures" ) ;
    if ($ProcessTiff)
      { Report("Option", "UsingTiff") }
    InitializeFigures ;
    HandleEpsFigures ;
    HandleTifFigures ;
    FlushFigures }

#D \extras
#D   {logfiles}
#D
#D This (poor man's) log file scanning routine filters
#D overfull box messages from a log file (\type{\hbox},
#D \type{\vbox} or both). The collected problems are saved
#D in \type{texutil.log}. One can specify a selection
#D criterium.
#D
#D \CONTEXT\ reports unknown entities. These can also be
#D filtered. When using fast computers, or when processing
#D files in batch, one has to rely on the log files and/or
#D this filter.

$Unknown = "onbekend|unknown|unbekant" ;

sub FlushLogTopic
  { unless ($TopicFound)
     { $TopicFound = 1 ;
       print ALL "\n% File: $FileName.log\n\n" } }

sub HandleLogFile
  { if ($ProcessBox)
      { Report("Option", "FilteringBoxes", "(\\vbox & \\hbox)") ;
        $Key = "[h|v]box" }
    elsif ($ProcessHBox)
      { Report("Option", "FilteringBoxes", "(\\hbox)") ;
        $Key = "hbox" ;
        $ProcessBox = 1 }
    elsif ($ProcessVBox)
      { Report("Option", "FilteringBoxes", "(\\vbox)") ;
        $Key = "vbox" ;
        $ProcessBox = 1 }
    if (($ProcessBox) && ($ProcessCriterium))
      { Report("Option", "ApplyingCriterium") }
    if ($ProcessUnknown)
      { Report("Option", "FilteringUnknown") }
    unless (($ProcessBox) || ($ProcessUnknown))
      { ShowHelpInfo ;
        return }
    Report("Action",  "FilteringLogFile" ) ;
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { $NOfBoxes = 0 ;
        $NOfMatching = 0 ;
        $NOfUnknown = 0 ;
        Report("OutputFile", "texutil.log") ;
        CheckInputFiles ($InputFile) ;
        open ( ALL, ">texutil.log" ) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = split (/\./, $FullName, 2) ;
            if (! open (LOG, "$FileName.log"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            elsif (-e "$FileName.tex")
              { $TopicFound = 0 ;
                Report("InputFile", "$FileName.log") ;
                while ($SomeLine=<LOG>)
                  { chomp ;
                    if (($ProcessBox) && ($SomeLine =~ /Overfull \\$Key/))
                      { ++$NOfBoxes ;
                        $SomePoints = $SomeLine ;
                        $SomePoints =~ s/.*\((.*)pt.*/$1/ ;
                        if ($SomePoints>=$ProcessCriterium)
                          { ++$NOfMatching ;
                            FlushLogTopic ;
                            print ALL "$SomeLine" ;
                            $SomeLine=<LOG> ;
                            print ALL $SomeLine } }
                    if (($ProcessUnknown) && ($SomeLine =~ /$Unknown/io))
                     { ++$NOfUnknown ;
                       FlushLogTopic ;
                       print ALL "$SomeLine" } } } }
        close (ALL) ;
        unless (($NOfBoxes) ||($NOfUnknown))
          { unlink "texutil.log" }
        if ($ProcessBox)
          { Report ( "NOfBoxes" , "$NOfBoxes", "->", $NOfMatching, "Overfull") }
        if ($ProcessUnknown)
          { Report ( "NOfUnknown", "$NOfUnknown") } } }

#D We're done! All this actions and options are organized in
#D one large conditional:

                              ShowBanner       ;

if     ($UnknownOptions   ) { ShowHelpInfo     } # not yet done
elsif  ($ProcessReferences) { HandleReferences }
elsif  ($ProcessDocuments ) { HandleDocuments  }
elsif  ($ProcessSources   ) { HandleSources    }
elsif  ($ProcessSetups    ) { HandleSetups     }
elsif  ($ProcessTemplates ) { HandleEditorCues }
elsif  ($ProcessInfos     ) { HandleEditorCues }
elsif  ($ProcessFigures   ) { HandleFigures    }
elsif  ($ProcessLogFile   ) { HandleLogFile    }
elsif  ($ProcessHelp      ) { ShowHelpInfo     } # redundant
else                        { ShowHelpInfo     }

#D So far.
