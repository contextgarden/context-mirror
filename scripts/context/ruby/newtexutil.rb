require 'base/logger'
require 'base/texutil'

logger = Logger.new('TeXUtil')

filename = ARGV[0] || 'tuitest'

if tu = TeXUtil::Converter.new(logger) and tu.loaded(filename) then
    tu.saved if tu.processed
end

# if     ($UnknownOptions   ) { ShowHelpInfo     } # not yet done
# elsif  ($ProcessReferences) { HandleReferences }
# elsif  ($ProcessFigures   ) { HandleFigures    }
# elsif  ($ProcessLogFile   ) { HandleLogFile    }
# elsif  ($PurgeFiles       ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --purge    $args") }
# elsif  ($PurgeAllFiles    ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --purgeall $args") }
# elsif  ($ProcessDocuments ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --document $args") }
# elsif  ($AnalyzeFile      ) { my $args = @ARGV.join(' ') ; system("texmfstart pdftools --analyze  $args") }
# elsif  ($FilterPages      ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --filter   $args") }
# elsif  ($ProcessHelp      ) { ShowHelpInfo     } # redundant
# else                        { ShowHelpInfo     }
