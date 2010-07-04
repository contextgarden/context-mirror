if not modules then modules = { } end modules ['data-tmf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--  =  <<
--  ?  ??
--  <  +=
--  >  =+

function resolvers.load_tree(tree)
    if type(tree) == "string" and tree ~= "" then

        local getenv, setenv = resolvers.getenv, resolvers.setenv

        -- later might listen to the raw osenv var as well
        local texos   = "texmf-" .. os.platform

        local oldroot = environment.texroot
        local newroot = file.collapse_path(tree)

        local newtree = file.join(newroot,texos)
        local newpath = file.join(newtree,"bin")

        if not lfs.isdir(newtree) then
            logs.simple("no '%s' under tree %s",texos,tree)
            os.exit()
        end
        if not lfs.isdir(newpath) then
            logs.simple("no '%s/bin' under tree %s",texos,tree)
            os.exit()
        end

        local texmfos = newtree

        environment.texroot = newroot
        environment.texos   = texos
        environment.texmfos = texmfos

        setenv('SELFAUTOPARENT', newroot)
        setenv('SELFAUTODIR',    newtree)
        setenv('SELFAUTOLOC',    newpath)
        setenv('TEXROOT',        newroot)
        setenv('TEXOS',          texos)
        setenv('TEXMFOS',        texmfos)
        setenv('TEXROOT',        newroot)
        setenv('TEXMFCNF',       resolvers.luacnfspec)
        setenv("PATH",           newpath .. io.pathseparator .. getenv("PATH"))

        logs.simple("changing from root '%s' to '%s'",oldroot,newroot)
        logs.simple("prepending '%s' to binary path",newpath)
        logs.simple()
    end
end
