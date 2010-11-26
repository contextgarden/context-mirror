if not modules then modules = { } end modules ['data-tex'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- special functions that deal with io

local format, lower = string.format, string.lower
local unpack = unpack or table.unpack

local trace_locating = false trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

local checkgarbage = utilities.garbagecollector and utilities.garbagecollector.check

function finders.generic(tag,filename,filetype)
    local foundname = resolvers.findfile(filename,filetype)
    if foundname and foundname ~= "" then
        if trace_locating then
            report_resolvers("%s finder: file '%s' found",tag,filename)
        end
        return foundname
    else
        if trace_locating then
            report_resolvers("%s finder: unknown file '%s'",tag,filename)
        end
        return unpack(finders.notfound)
    end
end

-- -- keep this one as reference as it's the first version
--
-- resolvers.filters = resolvers.filters or { }
--
-- local input_translator, utf_translator, user_translator = nil, nil, nil
--
-- function resolvers.filters.install(name,func)
--         if name == "input" then input_translator = func
--     elseif name == "utf"   then utf_translator   = func
--     elseif name == "user"  then user_translator  = func end
-- end
--
-- function openers.textopener(filename,file_handle,tag)
--     local u = unicode.utftype(file_handle)
--     local t = { }
--     if u > 0  then
--         if trace_locating then
--             report_resolvers("%s opener, file '%s' opened using method '%s'",tag,filename,unicode.utfname[u])
--         end
--         local l
--         local data = file_handle:read("*a")
--         if u > 2 then
--             l = unicode.utf32_to_utf8(data,u==4)
--         elseif u > 1 then
--             l = unicode.utf16_to_utf8(data,u==2)
--         else
--             l = string.splitlines(data)
--         end
--         file_handle:close()
--         t = {
--             utftype = u, -- may go away
--             lines = l,
--             current = 0, -- line number, not really needed
--             handle = nil,
--             noflines = #l,
--             close = function()
--                 if trace_locating then
--                     report_resolvers("%s closer, file '%s' closed",tag,filename)
--                 end
--                 logs.show_close(filename)
--                 t = nil
--             end,
--             reader = function(self)
--                 self = self or t
--                 local current, lines = self.current, self.lines
--                 if current >= #lines then
--                     return nil
--                 else
--                     current = current + 1
--                     self.current = current
--                     local line = lines[current]
--                     if not line then
--                         return nil
--                     elseif line == "" then
--                         return ""
--                     else
--                         if input_translator then
--                             line = input_translator(line)
--                         end
--                         if utf_translator then
--                             line = utf_translator(line)
--                         end
--                         if user_translator then
--                             line = user_translator(line)
--                         end
--                         return line
--                     end
--                 end
--             end
--         }
--     else
--         if trace_locating then
--             report_resolvers("%s opener, file '%s' opened",tag,filename)
--         end
--         -- todo: file;name -> freeze / eerste regel scannen -> freeze
--         --~ local data = lpegmatch(getlines,file_handle:read("*a"))
--         --~ local n = 0
--         t = {
--             reader = function() -- self
--                 local line = file_handle:read()
--                 --~ n = n + 1
--                 --~ local line = data[n]
--                 --~ print(line)
--                 if not line then
--                     return nil
--                 elseif line == "" then
--                     return ""
--                 else
--                     if input_translator then
--                         line = input_translator(line)
--                     end
--                     if utf_translator then
--                         line = utf_translator(line)
--                     end
--                     if user_translator then
--                         line = user_translator(line)
--                     end
--                     return line
--                 end
--             end,
--             close = function()
--                 if trace_locating then
--                     report_resolvers("%s closer, file '%s' closed",tag,filename)
--                 end
--                 logs.show_close(filename)
--                 file_handle:close()
--                 t = nil
--                 collectgarbage("step") -- saves some memory, maybe checkgarbage but no #
--             end,
--             handle = function()
--                 return file_handle
--             end,
--             noflines = function()
--                 t.noflines = io.noflines(file_handle)
--                 return t.noflines
--             end
--         }
--     end
--     return t
-- end


-- the main text reader --

local sequencers = utilities.sequencers

local fileprocessor = nil
local lineprocessor = nil

local textfileactions = sequencers.reset {
    arguments    = "str,filename",
    returnvalues = "str",
    results      = "str",
}

local textlineactions = sequencers.reset {
    arguments    = "str,filename,linenumber",
    returnvalues = "str",
    results      = "str",
}

openers.textfileactions = textfileactions
openers.textlineactions = textlineactions

sequencers.appendgroup(textfileactions,"system")
sequencers.appendgroup(textfileactions,"user")

sequencers.appendgroup(textlineactions,"system")
sequencers.appendgroup(textlineactions,"user")

function openers.textopener(filename,file_handle,tag)
    if trace_locating then
        report_resolvers("%s opener, file '%s' opened using method '%s'",tag,filename,unicode.utfname[u])
    end
    if textfileactions.dirty then
        fileprocessor = sequencers.compile(textfileactions)
    end
    local lines = io.loaddata(filename)
    local kind = unicode.filetype(lines)
    if kind == "utf-16-be" then
        lines = unicode.utf16_to_utf8_be(lines)
    elseif kind == "utf-16-le" then
        lines = unicode.utf16_to_utf8_le(lines)
    elseif kind == "utf-32-be" then
        lines = unicode.utf32_to_utf8_be(lines)
    elseif kind == "utf-32-le" then
        lines = unicode.utf32_to_utf8_le(lines)
    else -- utf8 or unknown
        lines = fileprocessor(lines,filename) or lines
        lines = string.splitlines(lines)
    end
    local t = {
        lines = lines,
        current = 0,
        handle = nil,
        noflines = #lines,
        close = function()
            if trace_locating then
                report_resolvers("%s closer, file '%s' closed",tag,filename)
            end
            logs.show_close(filename)
            t = nil
        end,
        reader = function(self)
            self = self or t
            local current, noflines = self.current, self.noflines
            if current >= noflines then
                return nil
            else
                current = current + 1
                self.current = current
                local line = lines[current]
                if not line then
                    return nil
                elseif line == "" then
                    return ""
                else
                    if textlineactions.dirty then
                        lineprocessor = sequencers.compile(textlineactions)
                    end
                    return lineprocessor(line,filename,current) or line
                end
            end
        end
    }
    return t
end

-- -- --

function openers.generic(tag,filename)
    if filename and filename ~= "" then
        local f = io.open(filename,"r")
        if f then
            logs.show_open(filename) -- todo
            if trace_locating then
                report_resolvers("%s opener, file '%s' opened",tag,filename)
            end
            return openers.textopener(filename,f,tag)
        end
    end
    if trace_locating then
        report_resolvers("%s opener, file '%s' not found",tag,filename)
    end
    return unpack(openers.notfound)
end

function loaders.generic(tag,filename)
    if filename and filename ~= "" then
        local f = io.open(filename,"rb")
        if f then
            logs.show_load(filename)
            if trace_locating then
                report_resolvers("%s loader, file '%s' loaded",tag,filename)
            end
            local s = f:read("*a")
            if checkgarbage then
                checkgarbage(#s)
            end
            f:close()
            if s then
                return true, s, #s
            end
        end
    end
    if trace_locating then
        report_resolvers("%s loader, file '%s' not found",tag,filename)
    end
    return unpack(loaders.notfound)
end

function finders.tex(filename,filetype)
    return finders.generic('tex',filename,filetype)
end

function openers.tex(filename)
    return openers.generic('tex',filename)
end

function loaders.tex(filename)
    return loaders.generic('tex',filename)
end

function resolvers.findtexfile(filename, filetype)
    return resolvers.methodhandler('finders',filename, filetype)
end

function resolvers.opentexfile(filename)
    return resolvers.methodhandler('openers',filename)
end

function resolvers.openfile(filename)
    local fullname = resolvers.findtexfile(filename)
    if fullname and (fullname ~= "") then
        return resolvers.opentexfile(fullname)
    else
        return nil
    end
end

function resolvers.loadtexfile(filename, filetype)
    -- todo: apply filters
    local ok, data, size = resolvers.loadbinfile(filename, filetype)
    return data or ""
end

resolvers.texdatablob = resolvers.loadtexfile
