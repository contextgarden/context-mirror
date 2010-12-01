if not modules then modules = { } end modules ['data-tex'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_locating = false trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

local resolvers = resolvers

local sequencers    = utilities.sequencers
local methodhandler = resolvers.methodhandler

local fileprocessor = nil
local lineprocessor = nil

local textfileactions = sequencers.reset {
    arguments    = "str,filename",
    returnvalues = "str",
    results      = "str",
}

local textlineactions = sequencers.reset {
    arguments    = "str,filename,linenumber,noflines",
    returnvalues = "str",
    results      = "str",
}

local helpers     = resolvers.openers.helpers
local appendgroup = sequencers.appendgroup

helpers.textfileactions = textfileactions
helpers.textlineactions = textlineactions

appendgroup(textfileactions,"before") -- user
appendgroup(textfileactions,"system") -- private
appendgroup(textfileactions,"after" ) -- user

appendgroup(textlineactions,"before") -- user
appendgroup(textlineactions,"system") -- private
appendgroup(textlineactions,"after" ) -- user

function helpers.textopener(tag,filename,file_handle)
    local lines
    if not file_handle then
        lines = io.loaddata(filename)
    elseif type(file_handle) == "string" then
        lines = file_handle
    elseif type(file_handle) == "table" then
        lines = file_handle
    elseif file_handle then
        lines = file_handle:read("*a")
        file_handle:close()
    end
    if type(lines) == "string" then
        local kind = unicode.filetype(lines)
        if trace_locating then
            report_resolvers("%s opener, '%s' opened using method '%s'",tag,filename,kind)
        end
        if kind == "utf-16-be" then
            lines = unicode.utf16_to_utf8_be(lines)
        elseif kind == "utf-16-le" then
            lines = unicode.utf16_to_utf8_le(lines)
        elseif kind == "utf-32-be" then
            lines = unicode.utf32_to_utf8_be(lines)
        elseif kind == "utf-32-le" then
            lines = unicode.utf32_to_utf8_le(lines)
        else -- utf8 or unknown
            if textfileactions.dirty then -- maybe use autocompile
                fileprocessor = sequencers.compile(textfileactions)
            end
            lines = fileprocessor(lines,filename) or lines
            lines = string.splitlines(lines)
        end
    elseif trace_locating then
        report_resolvers("%s opener, '%s' opened",tag,filename)
    end
    return {
        filename    = filename,
        noflines    = #lines,
        currentline = 0,
        close       = function()
            if trace_locating then
                report_resolvers("%s closer, '%s' closed",tag,filename)
            end
            logs.show_close(filename)
            t = nil
        end,
        reader      = function(self)
            self = self or t
            local currentline, noflines = self.currentline, self.noflines
            if currentline >= noflines then
                return nil
            else
                currentline = currentline + 1
                self.currentline = currentline
                local content = lines[currentline]
                if not content then
                    return nil
                elseif content == "" then
                    return ""
                else
                    if textlineactions.dirty then
                        lineprocessor = sequencers.compile(textlineactions) -- maybe use autocompile
                    end
                    return lineprocessor(content,filename,currentline,noflines) or content
                end
            end
        end
    }
end

function resolvers.findtexfile(filename,filetype)
    return methodhandler('finders',filename,filetype)
end

function resolvers.opentexfile(filename)
    return methodhandler('openers',filename)
end

function resolvers.openfile(filename)
    local fullname = methodhandler('finders',filename)
    return fullname and fullname ~= "" and methodhandler('openers',fullname) or nil
end

function resolvers.loadtexfile(filename,filetype)
    -- todo: optionally apply filters
    local ok, data, size = resolvers.loadbinfile(filename, filetype)
    return data or ""
end

resolvers.texdatablob = resolvers.loadtexfile

local function installhandler(namespace,what,where,func)
    if not func then
        where, func = "after", where
    end
    if where == "before" or where == "after" then
        sequencers.appendaction(namespace,where,func)
    else
        report_resolvers("installing input %s handlers in %s is not possible",what,tostring(where))
    end
end

function resolvers.installinputlinehandler(...) installhandler(helpers.textlineactions,"line",...) end
function resolvers.installinputfilehandler(...) installhandler(helpers.textfileactions,"file",...) end

-- local basename = file.basename
-- resolvers.installinputlinehandler(function(str,filename,linenumber,noflines)
--     logs.simple("[lc] file: %s, line: %s of %s, length: %s",basename(filename),linenumber,noflines,#str)
-- end)
-- resolvers.installinputfilehandler(function(str,filename)
--     logs.simple("[fc] file: %s, length: %s",basename(filename),#str)
-- end)
