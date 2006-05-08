" Vim syntax file
" Language:         ConTeXt typesetting engine
" Maintainer:       Nikolai Weibull <nikolai+work.vim@bitwi.se>
" Latest Revision:  2005-07-04

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword contextTodo       TODO FIXME XXX NOTE

"syn region  contextComment    display oneline start='%' end='\n'
"                              \ contains=contextTodo
"syn region  contextComment    display oneline start='^\s*%[CDM]' end='\n'
"                              \ contains=ALL

syn match  contextComment    '%.*' display
                              \ contains=contextTodo
syn match  contextComment    '^\s*%[CDM]*.*' display
                              \ contains=ALL

syn match   contextStatement  display '\\[a-zA-Z@]\+' contains=@NoSpell

syn match   contextBlockDelim display '\\\%(start\|stop\)\a\+'
                              \ contains=@NoSpell

syn match   contextDelimiter  '[][{}]'

syn match   contextEscaped    display '\\\_[\{}|&%$ ]'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\type\z(\A\)' end='\z1'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\type\={' end='}'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\type\=<<' end='>>'
syn region  contextEscaped    matchgroup=contextPreProc
                              \ start='\\start\z(\a*\%(typing\|typen\)\)'
                              \ end='\\stop\z1'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\\h\+Type{' end='}'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\Typed\h\+{' end='}'

"syn region  contextMath       matchgroup=contextMath start='\$' end='\$'
"                              \ contains=contextStatement

syn match   contextBuiltin    '\\\%(newif\|def\|gdef\|global\|let\|glet\|bgroup\)\>'
                              \ contains=@NoSpell
syn match   contextBuiltin    '\\\%(begingroup\|egroup\|endgroup\|long\|catcode\)\>'
                              \ contains=@NoSpell
syn match   contextBuiltin    '\\\%(unprotect\|unexpanded\|if\|else\|fi\|ifx\)\>'
                              \ contains=@NoSpell
syn match   contextBuiltin    '\\\%(futurelet\|protect\)\>' contains=@NoSpell
syn match   contextBuiltin    '\\\%([lr]q\)\>' contains=@NoSpell

syn match   contextPreProc    '^\s*\\\%(start\|stop\)\=\%(component\|environment\|project\|product\).*$'
                              \ contains=@NoSpell
syn match   contextPreProc    '^\s*\\input\s\+.*$' contains=@NoSpell

syn match   contextSectioning '\\chapter\>' contains=@NoSpell
syn match   contextSectioning '\\\%(sub\)*section\>' contains=@NoSpell

syn match   contextSpecial    '\\crlf\>\|\\par\>\|-\{2,3}\||[<>/]\=|'
                              \ contains=@NoSpell
syn match   contextSpecial    '\\[`'"]'
syn match   contextSpecial    +\\char\%(\d\{1,3}\|'\o\{1,3}\|"\x\{1,2}\)\>+
                              \ contains=@NoSpell
syn match   contextSpecial    '\^\^.'
syn match   contextSpecial    '`\%(\\.\|\^\^.\|.\)'

syn match   contextStyle      '\\\%(em\|tt\|rm\|ss\|hw\|cg\|mf\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(CAP\|Cap\|cap\|Caps\|kap\|nocap\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(Word\|WORD\|Words\|WORDS\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(vi\{1,3}\|ix\|xi\{0,2}\)\>'
                              \ contains=@NoSpell
"syn match   contextFont       '\\\%(tf[abcdx]\|bfx\|[is]lx\)\>'
"                              \ contains=@NoSpell
syn match   contextFont       '\\\%(tf\|b[fsi]\|s[cl]\|it\|os\)\%(\|[xabcd]\|xx\)\>'
                              \ contains=@NoSpell
" missing:
"  \tx, \txx, is \t[abcd] also possible?
"  \rmsl, \ssbf, \sssl, \tttf ... I didn't figure out yet how they are used
"  \rmd ...
"  is \em[xabcd] possible?
"  mm
"  ex, mi, sy - what's that?

syn match   contextDimension  '[+-]\=\s*\%(\d\+\%([.,]\d*\)\=\|[.,]\d\+\)\s*\%(true\)\=\s*\%(p[tc]\|in\|bp\|c[mc]\|mm\|dd\|sp\|e[mx]\)\>'
                              \ contains=@NoSpell


" Put the metafun syntax file in @metafunTop
"
" TODO: should be changed to metafun once the support is there
" javascript should probably be adapted to PDF specification too, but it
" changes in every version anyway and often doesn't work either
"
syn include @metafunTop syntax/mp.vim
unlet b:current_syntax
"syn cluster @metafunTop contains=@mmetafunTop remove=texComment
" for some reason I can't make both metapost and javascript working at the same time

"syn region metafunBlock matchgroup=metafunDelim start=#\\startMPpage# skip=#%.*\\stopMPpage# end=#\\stopMPpage# keepend contains=@metafunTop
"syn region metafunBlock matchgroup=metafunDelim start=#\\startMPpage\(\s|$\)# skip=#%.*\\stopMPpage# matchgroup=metafunDelim end=#\\stopMPpage\(\s|$\)# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startMPpage# skip=#%.*\\stopMPpage# matchgroup=metafunDelim end=#\\stopMPpage# transparent keepend contains=@metafunTop
"syn region metafunBlock matchgroup=metafunDelim start=#\\startMPpage#hs=e-2 skip=#%.*\\stopMPpage# matchgroup=metafunDelim end=#\\stopMPpage#he=s-1 keepend contains=@metafunTop
" TODO: \startuseMPgraphic{the name} - "the name" has to be catched and
" typeset in ConTeXt, not in metapost!!!
syn region metafunBlock matchgroup=metafunDelim start=#\\startMPcode# skip=#%.*\\stopMPcode# end=#\\stopMPcode# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startMPinclusions# skip=#%.*\\stopMPinclusions# end=#\\stopMPinclusions# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startMPgraphic# skip=#%.*\\stopMPgraphic# end=#\\stopMPgraphic# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startMPdrawing# skip=#%.*\\stopMPdrawing# end=#\\stopMPdrawing# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startuseMPgraphic# skip=#%.*\\stopuseMPgraphic# end=#\\stopuseMPgraphic# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startreusableMPgraphic# skip=#%.*\\stopreusableMPgraphic# end=#\\stopreusableMPgraphic# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startuniqueMPgraphic# skip=#%.*\\stopuniqueMPgraphic# end=#\\stopuniqueMPgraphic# transparent keepend contains=@metafunTop
syn region metafunBlock matchgroup=metafunDelim start=#\\startMPrun# skip=#%.*\\stopMPrun# end=#\\stopMPrun# transparent keepend contains=@metafunTop

hi def link metafundelim contextBlockDelim

syn match contextURL '\\useURL\s*\[abc\]'


hi def link contextTodo       Todo
hi def link contextComment    Comment
hi def link contextEscaped    Special
"hi def link contextStatement  Identifier
hi def link contextStatement  Statement
hi def link contextMath       String
hi def link contextBlockDelim Keyword
hi def link contextBuiltin    Keyword
hi def link contextDelimiter  Delimiter
hi def link contextPreProc    PreProc
hi def link contextSectioning PreProc
hi def link contextSpecial    Special
hi def link contextStyle      contextType
hi def link contextFont       contextType
hi def link contextType       Type
hi def link contextDimension  Number

hi def link metafunBlock String
hi def link contextURL String

let b:current_syntax = "context"

let &cpo = s:cpo_save
unlet s:cpo_save



