Some Basic information
----------------------

The first public versions of ConTeXt date from around 1996. There
are currently two versions of ConTeXt:

    MkII: to be used with pdfTeX and XeTeX
    MkIV: to be used with LuaTeX

In 2008 at the second ConTeXt conference the decision was made to
freeze MkII. This means that only bugs are fixed and apart from an
occasional addition no active development takes place. This is no
real problem as the engines don't change much either.

Early 2011 the code base between MkII and MkIV got split completely
and there is no shared code any longer, apart from some styles and
modules. From the perspective of ConteXt we now consider XeTeX to be
obsolete although we will keep supporting it in MkII. As pdftex is
still used in older workflows we will support that as long as it's
around.

The main files context.mkii and context.mkiv are normally not used
directly but instead we use the interface specific formats:

    cont-cs   czech
    cont-de   german
    cont-en   english us
    cont-fr   french
    cont-gb   english uk
    cont-it   italian
    cont-nl   dutch
    cont-pe   persian
    cont-ro   romanian

A MkII format is made with:

    texexec --make en nl metafun

A MkIV format is made with:

    context --make en nl

As MetaPost is part of LuaTeX there is no need for a special MetaFun
format. Also, when you update ConTeXt, a new format will be generated
automatically.

You can preset commands etc in the file:

    cont-sys.mkii  a system file loaded at runtime
    cont-sys.mkiv  a system file loaded at runtime

In the case of MkII, there is a fallback on cont-sys.tex (backward
compatibility). If no file is found the file cont-sys.rme is loaded
(only for MkII). For MkIV this file is normally not needed.

For questions and remarks on ConTeXt, one can subscribe to the list:

    ntg-context@ntg.nl

by sending the message

    subscribe ntg-context

to the list server:

    majordomo@ntg.nl

A good place to get information is the ConTeXt wiki:

    contextgarden.net

One can also find more info at:

    www.pragma-ade.com

or at the mirror sites mentioned there.

Don't hesitate to ask questions. ConTeXt can do a lot, but the manuals
always lag behind and can be incomplete.

-------------------------
Hans Hagen, pragma @ wxs . nl
