if not modules then modules = { } end modules ['mtx-server-ctx-fonttest'] = {
    version   = 1.001,
    comment   = "Font Feature Tester",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

dofile(resolvers.find_file("l-aux.lua","tex"))
dofile(resolvers.find_file("trac-lmx.lua","tex"))
dofile(resolvers.find_file("font-ott.lua","tex"))
dofile(resolvers.find_file("font-syn.lua","tex"))
dofile(resolvers.find_file("font-mis.lua","tex"))
dofile(resolvers.find_file("font-otp.lua","tex"))

local format, gsub, concat, match, find = string.format, string.gsub, table.concat, string.match, string.find

local sample_line = "This is a sample line!"
local tempname    = "mtx-server-ctx-fonttest-temp"
local temppath    = caches.setpath("temp","mtx-server-ctx-fonttest")
local basename    = "mtx-server-ctx-fonttest-data.lua"
local basepath    = temppath

for _, suffix in ipairs { "tex", "pdf", "log" } do
    os.remove(file.join(temppath,file.addsuffix(tempname,suffix)))
end

local process_templates = { }

process_templates.default = [[
\starttext
    \setcharactermirroring[1]
    \definefontfeature[sample][%s]
    \definedfont[name:%s*sample]
    \startTEXpage[offset=3pt]
        \detokenize{%s}
    \stopTEXpage
\stoptext
]]

process_templates.cache = [[
\starttext
    \definedfont[name:%s]
    \startTEXpage[offset=3pt]
        cached: \detokenize{%s}
    \stopTEXpage
\stoptext
]]

process_templates.trace = [[
\usemodule[fnt-20]

\definefontfeature[sample][%s]

\setupcolors[state=start]

\setcharactermirroring[1]

\setvariables
  [otftracker]
  [title=Test Run,
   font=name:%s,
   direction=0,
   features=sample,
   sample={‍\detokenize{%s}}]
]]

local javascripts = [[
function selected_radio(name) {
    var form = document.forms["main-form"] ;
    var script = form.elements[name] ;
	if (script) {
        var n = script.length ;
        if (n) {
            for (var i=0; i<n; i++) {
                if (script[i].checked) {
                    return script[i].value ;
                }
            }
		}
	}
    return "" ;
}

function reset_valid() {
    var fields = document.getElementsByTagName("span") ;
    for (var i=0; i<fields.length; i++) {
        var e = fields[i]
        if (e) {
            if (e.className == "valid") {
                e.className = "" ;
            }
        }
    }
}

function set_valid() {
    var script = selected_radio("script") ;
    var language = selected_radio("language") ;
    if (script && language) {
        var s = feature_hash[script] ;
        if (s) {
            for (l in s) {
                var e = document.getElementById("t-l-" + l) ;
                if (e) {
                    e.className = "valid" ;
                }
            }
            var l = s[language] ;
            if (l) {
                for (i in l) {
                    var e = document.getElementById("t-f-" + i) ;
                    if (e) {
                        e.className = "valid" ;
                    }
                }
            }
            var e = document.getElementById("t-s-" + script) ;
            if (e) {
                e.className = "valid" ;
            }
        }
    }
}

function check_form() {
    reset_valid() ;
    set_valid() ;
}

function check_script() {
    reset_valid() ;
    set_valid() ;
}

function check_language() {
    reset_valid() ;
    set_valid() ;
}

function check_feature() {
    // not needed
}
]]

local cache = { }

local function showfeatures(f)
    if f then
        local features = cache[f]
        if features == nil then
            features = fonts.get_features(f)
            if not features then
                logs.simple("building cache for '%s'",f)
                io.savedata(file.join(temppath,file.addsuffix(tempname,"tex")),format(process_templates.cache,f,f))
                os.execute(format("mtxrun --path=%s --script context --once --batchmode %s",temppath,tempname))
                features = fonts.get_features(f)
            end
            cache[f] = features or false
            logs.simple("caching info of '%s'",f)
        else
            logs.simple("using cached info of '%s'",f)
        end
        if features then
            local scr, lan, fea, rev = { }, { }, { }, { }
            local function show(what)
                local data = features[what]
                if data and next(data) then
                    for f,ff in pairs(data) do
                        if find(f,"<") then
                            -- ignore aat for the moment
                        else
                            fea[f] = true
                            for s, ss in pairs(ff) do
                                if find(s,"%*") then
                                    -- ignore *
                                else
                                    scr[s] = true
                                    local rs = rev[s] if not rs then rs = {} rev[s] = rs end
                                    for k, l in pairs(ss) do
                                        if find(k,"%*") then
                                            -- ignore *
                                        else
                                            lan[k] = true
                                            local rsk = rs[k] if not rsk then rsk = { } rs[k] = rsk end
                                            rsk[f] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            for what, v in table.sortedpairs(features) do
                show(what)
            end
            local stupid = { }
            stupid[#stupid+1] = "var feature_hash = new Array ;"
            for s, sr in pairs(rev) do
                stupid[#stupid+1] = format("feature_hash['%s'] = new Array ;",s)
                for l, lr in pairs(sr) do
                    stupid[#stupid+1] = format("feature_hash['%s']['%s'] = new Array ;",s,l)
                    for f, fr in pairs(lr) do
                        stupid[#stupid+1] = format("feature_hash['%s']['%s']['%s'] = true ;",s,l,f)
                    end
                end
            end
            -- gpos feature script languages
            return {
                scripts = scr,
                languages = lan,
                features = fea,
                javascript = concat(stupid,"\n")
            }
        end
    end
end

local function select_font()
    local t = fonts.names.list(".*")
    if t then
        local listoffonts = { }
        local t = fonts.names.list(".*")
        if t then
            listoffonts[#listoffonts+1] = "<table>"
            listoffonts[#listoffonts+1] = "<tr><th>safe name</th><th>font name</th><th>filename</th><th>sub font&nbsp;</th><th>type</th></tr>"
            for k, id in ipairs(table.sortedkeys(t)) do
                local ti = t[id]
                local type, name, file, sub = ti[1], ti[2], ti[3], ti[4]
                if type == "otf" or  type == "ttf" or  type == "ttc" then
                    if sub then sub = "(sub)" else sub = "" end
                    listoffonts[#listoffonts+1] = format("<tr><td><a href='mtx-server-ctx-fonttest.lua?selection=%s'>%s</a></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",id,id,name,file,sub,type)
                end
            end
            listoffonts[#listoffonts+1] = "</table>"
            return concat(listoffonts,"\n")
        end
    end
    return "<b>no fonts</b>"
end

local edit_template = [[
    <textarea name='sampletext' rows='5' cols='100'>%s</textarea>
    <br/> <br/>name:&nbsp;<input type='text' name='name' size='20' value=%q/>&nbsp;&nbsp; title:&nbsp;<input type='text' name='title' size='40' value=%q/>
    <br/> <br/>scripts:&nbsp;%s
    <br/> <br/>languages:&nbsp;%s
    <br/> <br/>features:&nbsp;%s
    <br/> <br/>options:&nbsp;%s
]]

local result_template = [[
    <br/> <br/>
    <embed src="%s#toolbar=0&amp;navpanes=0&amp;scrollbar=0" width="100%%"/>
    <br/> <br/> results:
    <a href='%s' target="source">tex file</a>
    <a href='%s' target="result">pdf file</a>
    <br/> <br/>
]]

scripts.webserver.registerpath(temppath)

local function edit_font(currentfont,detail,tempname)
    local fontname, fontfile, issub = fonts.names.specification(currentfont or "")
    local htmldata = showfeatures(fontfile)
    if htmldata then
        local features, languages, scripts, options = { }, { }, { }, { }
        for k,v in ipairs(table.sortedkeys(htmldata.scripts)) do
            local s = fonts.otf.tables.scripts[v] or v
            if detail and v == detail.script then
                scripts[#scripts+1] = format("<input title='%s' id='s-%s' type='radio' name='script' value='%s' onclick='check_script()' checked='checked'/>&nbsp;<span id='t-s-%s'>%s</span>",s,v,v,v,v)
            else
                scripts[#scripts+1] = format("<input title='%s' id='s-%s' type='radio' name='script' value='%s' onclick='check_script()' />&nbsp;<span id='t-s-%s'>%s</span>",s,v,v,v,v)
            end
        end
        for k,v in ipairs(table.sortedkeys(htmldata.languages)) do
            local l = fonts.otf.tables.languages[v] or v
            if detail and v == detail.language then
                languages[#languages+1] = format("<input title='%s' id='l-%s' type='radio' name='language' value='%s' onclick='check_language()' checked='checked'/>&nbsp;<span id='t-l-%s'>%s</span>",l,v,v,v,v)
            else
                languages[#languages+1] = format("<input title='%s' id='l-%s' type='radio' name='language' value='%s' onclick='check_language()' />&nbsp;<span id='t-l-%s'>%s</span>",l,v,v,v,v)
            end
        end
        for k,v in ipairs(table.sortedkeys(htmldata.features)) do
            local f = fonts.otf.tables.features[v] or v
            if detail and detail["f-"..v] then
                features[#features+1] = format("<input title='%s' id='f-%s' type='checkbox' name='f-%s' onclick='check_feature()' checked='checked'/>&nbsp;<span id='t-f-%s'>%s</span>",f,v,v,v,v)
            else
                features[#features+1] = format("<input title='%s' id='f-%s' type='checkbox' name='f-%s' onclick='check_feature()' />&nbsp;<span id='t-f-%s'>%s</span>",f,v,v,v,v)
            end
        end
        for k, v in ipairs { "trace", "basemode" } do
            if detail and detail["o-"..v] then
                options[#options+1] = format("<input id='o-%s' type='checkbox' name='o-%s' checked='checked'/>&nbsp;%s",v,v,v)
            else
                options[#options+1] = format("<input id='o-%s' type='checkbox' name='o-%s'/>&nbsp;%s",v,v,v)
            end
        end
        local e = format(edit_template,
            (detail and detail.sampletext) or sample_line,(detail and detail.name) or "no name",(detail and detail.title) or "",
            concat(scripts,"  "),concat(languages,"  "),concat(features,"  "),concat(options,"  "))
        if tempname then
            local pdffile, texfile = file.addsuffix(tempname,"pdf"), file.addsuffix(tempname,"tex")
            local r = format(result_template,pdffile,texfile,pdffile)
            return e .. r, htmldata.javascript or ""
        else
            return e, htmldata.javascript or ""
        end
    else
        return "error, nothing set up yet"
    end
end

local function process_font(currentfont,detail) -- maybe just fontname
    local fontname, fontfile, issub = fonts.names.specification(currentfont or "")
    local features = {
        "mode=node",
        format("language=%s",detail.language or "dflt"),
        format("script=%s",detail.script or "dflt"),
    }
    for k,v in pairs(detail) do
        local f = match(k,"^f%-(.*)$")
        if f then
            features[#features+1] = format("%s=yes",f)
        end
    end
    local variant = process_templates.default
    if detail["o-trace"] then
        variant = process_templates.trace
    end
    local sample = string.strip(detail.sampletext or "")
    if sample == "" then sample = sample_line end
    logs.simple("sample text: %s",sample)
    io.savedata(file.join(temppath,file.addsuffix(tempname,"tex")),format(variant,concat(features,","),currentfont,sample))
    os.execute(format("mtxrun --path=%s --script context --once --batchmode %s",temppath,tempname))
    return edit_font(currentfont,detail,tempname)
end

local tex_template = [[
<pre><tt>
%s
</tt></pre>
]]

local function show_source(currentfont,detail)
    if tempname and tempname ~= "" then
        return format(tex_template,io.loaddata(file.join(temppath,file.addsuffix(tempname,"tex"))) or "no source yet")
    else
        return "no source file"
    end
end

local function show_log(currentfont,detail)
    if tempname and tempname ~= "" then
        local data = io.loaddata(file.join(temppath,file.addsuffix(tempname,'log'))) or "no log file yet"
        data = gsub(data,"[%s%%]*begin of optionfile.-end of optionfile[%s%%]*","\n")
        return format(tex_template,data)
    else
        return "no log file"
    end
end

local function show_font(currentfont,detail)
    local fontname, fontfile, issub = fonts.names.specification(currentfont or "")
    local features = fonts.get_features(fontfile)
    local result = { }
    result[#result+1] = format("<h1>names</h1>",what)
    result[#result+1] = "<table>"
    result[#result+1] = format("<tr><td class='tc'>fontname:</td><td>%s</td></tr>",currentfont)
    result[#result+1] = format("<tr><td class='tc'>fullname:</td><td>%s</td></tr>",fontname)
    result[#result+1] = format("<tr><td class='tc'>filename:</td><td>%s</td></tr>",fontfile)
    result[#result+1] = "</table>"
    if features then
        for what, v in table.sortedpairs(features) do
            local data = features[what]
            if data and next(data) then
                result[#result+1] = format("<h1>%s features</h1>",what)
                result[#result+1] = "<table>"
                result[#result+1] = "<tr><th>feature</th><th>tag&nbsp;</th><th>script&nbsp;</th><th>languages&nbsp;</th></tr>"
                for f,ff in table.sortedpairs(data) do
                    local done = false
                    for s, ss in table.sortedpairs(ff) do
                        if s == "*"  then s       = "all" end
                        if ss  ["*"] then ss["*"] = nil ss.all = true end
                        if done then
                            f = ""
                        else
                            done = true
                        end
                        local title = fonts.otf.tables.features[f] or ""
                        result[#result+1] = format("<tr><td width='50%%'>%s&nbsp;&nbsp;</td><td><tt>%s&nbsp;&nbsp;</tt></td><td><tt>%s&nbsp;&nbsp;</tt></td><td><tt>%s&nbsp;&nbsp;</tt></td></tr>",title,f,s,concat(table.sortedkeys(ss)," "))
                    end
                end
                result[#result+1] = "</table>"
            end
        end
    else
        result[#result+1] = "<br/><br/>This font has no features."
    end
    return concat(result,"\n")
end


local info_template = [[
<pre><tt>
version   : %s
comment   : %s
author    : %s
copyright : %s

maillist  : ntg-context at ntg.nl
webpage   : www.pragma-ade.nl
wiki      : contextgarden.net
</tt></pre>
]]

local function info_about()
    local m = modules ['mtx-server-ctx-fonttest']
    return format(info_template,m.version,m.comment,m.author,m.copyright)
end

local save_template = [[
    the current setup has been saved:
    <br/> <br/>
    <table>
    <tr><td class='tc'>name&nbsp;      </td><td>%s</td></tr>
    <tr><td class='tc'>title&nbsp;     </td><td>%s</td></tr>
    <tr><td class='tc'>font&nbsp;      </td><td>%s</td></tr>
    <tr><td class='tc'>script&nbsp;    </td><td>%s</td></tr>
    <tr><td class='tc'>language&nbsp;  </td><td>%s</td></tr>
    <tr><td class='tc'>features&nbsp;  </td><td>%s</td></tr>
    <tr><td class='tc'>options&nbsp;   </td><td>%s</td></tr>
    <tr><td class='tc'>sampletext&nbsp;</td><td>%s</td></tr>
    </table>
]]

local function loadbase()
    local datafile = file.join(basepath,basename)
    local storage = io.loaddata(datafile) or ""
    if storage == "" then
        storage = { }
    else
        logs.simple("loading '%s'",datafile)
        storage = loadstring(storage)
        storage = (storage and storage()) or { }
    end
    return storage
end

local function loadstored(detail,currentfont,name)
    local storage = loadbase()
    storage = storage and storage[name]
    if storage then
        currentfont = storage.font
        detail.script = storage.script or detail.script
        detail.language = storage.language or detail.language
        detail.title = storage.title or detail.title
        detail.sampletext = storage.text or detail.sampletext
        detail.name = name or "no name"
        for k,v in pairs(storage.features) do
            detail["f-"..k] = v
        end
        for k,v in pairs(storage.options) do
            detail["o-"..k] = v
        end
    end
    detail.loadname = nil
    return detail, currentfont
end

local function savebase(storage,name)
    local datafile = file.join(basepath,basename)
    logs.simple("saving '%s' in '%s'",name or "data",datafile)
    io.savedata(datafile,table.serialize(storage,true))
end

local function deletestored(detail,currentfont,name)
    local storage = loadbase()
    if storage and name and storage[name] then
        logs.simple("deleting '%s' from base",name)
        storage[name] = nil
        savebase(storage)
    end
    detail.deletename = nil
    return detail, ""
end

local function save_font(currentfont,detail)
    local fontname, fontfile, issub = fonts.names.specification(currentfont or "")
    local name, title, script, language, features, options, text = currentfont, "", "dflt", "dflt", { }, { }, ""
    if detail then
        local htmldata = showfeatures(fontfile)
        script = detail.script or script
        language = detail.language or language
        text = string.strip(detail.sampletext or text)
        name = string.strip(detail.name or name)
        title = string.strip(detail.title or title)
        for k,v in pairs(htmldata.features) do
            if detail["f-"..k] then features[k] = true end
        end
        for k,v in ipairs { "trace", "basemode" } do
            if detail["o-"..v] then options[k] = true end
        end
    end
    if name == "" then
        name = "no name"
    end
    local storage = loadbase()
    storage[name] = {
        font = currentfont, title = title, script = script, language = language, features = features, options = options, text = text,
    }
    savebase(storage,name)
    return format(save_template,name,title,currentfont,script,language,concat(table.sortedkeys(features)," "),concat(table.sortedkeys(options)," "),text)
end

local function load_font(currentfont)
    local datafile = file.join(basepath,basename)
    local storage = loadbase(datafile)
    local result = {}
    result[#result+1] = format("<tr><th>del&nbsp;</th><th>name&nbsp;</th><th>font&nbsp;</th><th>fontname&nbsp;</th><th>script&nbsp;</th><th>language&nbsp;</th><th>features&nbsp;</th><th>title&nbsp;</th><th>sampletext&nbsp;</th></tr>")
    for k,v in table.sortedpairs(storage) do
        local fontname, fontfile, issub = fonts.names.specification(v.font or "")
        result[#result+1] = format("<tr><td><a href='mtx-server-ctx-fonttest.lua?deletename=%s'>x</a>&nbsp;</td><td><a href='mtx-server-ctx-fonttest.lua?loadname=%s'>%s</a>&nbsp;</td><td>%s&nbsp;</td<td>%s&nbsp;</td><td>%s&nbsp;</td><td>%s&nbsp;</td><td>%s&nbsp;</td><td>%s&nbsp;</td><td>%s&nbsp;</td></tr>",
            k,k,k,v.font,fontname,v.script,v.language,concat(table.sortedkeys(v.features)," "),v.title or "no title",v.text or "")
    end
    if #result == 1 then
        return "nothing saved yet"
    else
        return format("<table>%s</table>",concat(result,"\n"))
    end
end

local function reset_font(currentfont)
    return edit_font(currentfont)
end

local extras_template = [[
    <a href='mtx-server-ctx-fonttest.lua?extra=reload'>remake font database</a> (take some time)<br/><br/>
]]

local function do_extras(detail,currentfont,extra)
    return extras_template
end

local extras = { }

local function do_extra(detail,currentfont,extra)
    local e = extras[extra]
    if e then e(detail,currentfont,extra) end
    return do_extras(detail,currentfont,extra)
end

function extras.reload()
    local command = "mtxrun --script font --reload"
    logs.simple("run command: %s",command)
    os.execute(command)
    return do_extras()
end


local status_template = [[
    <input type="hidden" name="currentfont" value="%s" />
]]

function doit(configuration,filename,hashed)

    local start = os.clock()

    local detail = url.query(hashed.query or "")

    local currentfont = detail.currentfont
    local action      = detail.action
    local selection   = detail.selection

    local loadname    = detail.loadname
    local deletename  = detail.deletename
    local extra       = detail.extra

    if loadname and loadname ~= "" then
        detail, currentfont = loadstored(detail,currentfont,loadname)
        action = "process"
    elseif deletename and deletename ~= "" then
        detail, currentfont = deletestored(detail,currentfont,deletename)
        action = "load"
    elseif selection and selection ~= "" then
        currentfont = selection
    elseif extra and extra ~= "" then
        do_extra(detail,currentfont,extra)
        action = "extras"
    end

    lmx.restore()

    local fontname, fontfile, issub = fonts.names.specification(currentfont or "")

    if fontfile then
        lmx.variables['title-default'] = format('ConTeXt Font Tester: %s (%s)',fontname,fontfile)
    else
        lmx.variables['title-default'] = 'ConTeXt Font Tester'
    end

    lmx.variables['color-background-green']  = '#4F6F6F'
    lmx.variables['color-background-blue']   = '#6F6F8F'
    lmx.variables['color-background-yellow'] = '#8F8F6F'
    lmx.variables['color-background-purple'] = '#8F6F8F'

    lmx.variables['color-background-body']   = '#808080'
    lmx.variables['color-background-main']   = '#3F3F3F'
    lmx.variables['color-background-one']    = lmx.variables['color-background-green']
    lmx.variables['color-background-two']    = lmx.variables['color-background-blue']

    lmx.variables['title']                   = lmx.variables['title-default']

    lmx.set('title',                lmx.get('title'))
    lmx.set('color-background-one', lmx.get('color-background-green'))
    lmx.set('color-background-two', lmx.get('color-background-blue'))

    -- lua table and adapt

    lmx.set('formaction', "mtx-server-ctx-fonttest.lua")

    local menu = { }
    for k, v in ipairs { 'process', 'select', 'save', 'load', 'edit', 'reset', 'features', 'source', 'log', 'info', 'extras'} do
        menu[#menu+1] = format("<button name='action' value='%s' type='submit'>%s</button>",v,v)
    end
    lmx.set('menu', concat(menu,"&nbsp;"))

    logs.simple("action: %s",action or "no action")

    lmx.set("status",format(status_template,currentfont or ""))

    local result

    if action == "select" then
        lmx.set('maintext',select_font())
    elseif action == "info" then
        lmx.set('maintext',info_about())
    elseif action == "extras" then
        lmx.set('maintext',do_extras())
    elseif currentfont and currentfont ~= "" then
        if action == "save" then
            lmx.set('maintext',save_font(currentfont,detail))
        elseif action == "load" then
            lmx.set('maintext',load_font(currentfont,detail))
        elseif action == "source" then
            lmx.set('maintext',show_source(currentfont,detail))
        elseif action == "log" then
            lmx.set('maintext',show_log(currentfont,detail))
        elseif action == "features" then
            lmx.set('maintext',show_font(currentfont,detail))
        else
            local e, s
            if action == "process" then
                e, s = process_font(currentfont,detail)
            elseif action == "reset" then
                e, s = reset_font(currentfont)
            elseif action == "edit" then
                e, s = edit_font(currentfont,detail)
            else
                e, s = process_font(currentfont,detail)
            end
            lmx.set('maintext',e)
            lmx.set('javascriptdata',s)
            lmx.set('javascripts',javascripts)
            lmx.set('javascriptinit', "check_form()")
        end
    else
        lmx.set('maintext',select_font())
    end

    result = { content = lmx.convert('context-fonttest.lmx') }

    logs.simple("time spent on page: %0.03f seconds",os.clock()-start)

    return result

end

return doit, true

--~ make_lmx_page("test")
