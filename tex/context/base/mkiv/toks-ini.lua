if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tokens = tokens or { }

local tokens     = tokens
local token      = token -- the built in one
local next       = next
local tonumber   = tonumber
local tostring   = tostring
local utfchar    = utf.char
local char       = string.char
local printtable = table.print
local concat     = table.concat
local format     = string.format

if token.commands then

    local commands = token.commands()

    tokens.commands = utilities.storage.allocate(table.swapped(commands,commands))

else

    tokens.commands = { }

end

local scan_toks       = token.scan_toks
local scan_string     = token.scan_string
local scan_argument   = token.scan_argument
local scan_tokenlist  = token.scan_tokenlist
local scan_int        = token.scan_int
local scan_code       = token.scan_code
local scan_dimen      = token.scan_dimen
local scan_glue       = token.scan_glue
local scan_keyword    = token.scan_keyword
local scan_keyword_cs = token.scan_keyword_cs or scan_keyword
local scan_token      = token.scan_token
local scan_word       = token.scan_word
local scan_number     = token.scan_number
local scan_csname     = token.scan_csname
local scan_real       = token.scan_real
local scan_float      = token.scan_float

local get_next        = token.get_next

local set_macro       = token.set_macro
local get_macro       = token.get_macro
local get_meaning     = token.get_meaning
local get_cmdname     = token.get_cmdname
local set_char        = token.set_char
local set_lua         = token.set_lua

local create_token    = token.create
local new_token       = token.new
local is_defined      = token.is_defined
local is_token        = token.is_token

if not is_defined then

    is_defined = function(name)
        return get_cmdname(create_token(name)) ~= "undefined_cs"
    end

end

tokens.new            = new_token
tokens.create         = create_token
tokens.istoken        = is_token
tokens.isdefined      = is_defined
tokens.defined        = is_defined

local bits = {
    escape      = 0x00000001, -- 2^00
    begingroup  = 0x00000002, -- 2^01
    endgroup    = 0x00000004, -- 2^02
    mathshift   = 0x00000008, -- 2^03
    alignment   = 0x00000010, -- 2^04
    endofline   = 0x00000020, -- 2^05
    parameter   = 0x00000040, -- 2^06
    superscript = 0x00000080, -- 2^07
    subscript   = 0x00000100, -- 2^08
    ignore      = 0x00000200, -- 2^09
    space       = 0x00000400, -- 2^10 -- 1024
    letter      = 0x00000800, -- 2^11
    other       = 0x00001000, -- 2^12
    active      = 0x00002000, -- 2^13
    comment     = 0x00004000, -- 2^14
    invalid     = 0x00008000, -- 2^15
    --
    character   = 0x00001800, -- 2^11 + 2^12
    whitespace  = 0x00002400, -- 2^13 + 2^10 --    / needs more checking
    --
    open        = 0x00000402, -- 2^10 + 2^01 -- space + begingroup
    close       = 0x00000404, -- 2^10 + 2^02 -- space + endgroup
}

-- for k, v in next, bits do bits[v] = k end

tokens.bits = bits

local space_bits = bits.space

-- words are space or \relax terminated and the trailing space is gobbled; a word
-- can contain any non-space letter/other

local t = { } -- small optimization, a shared variable that is not reset

if scan_word then

    scan_number = function(base)
        local s = scan_word()
        if not s then
            return nil
        elseif base then
            return tonumber(s,base)
        else
            return tonumber(s)
        end
    end

else

    scan_word = function()
        local n = 0
        while true do
            local c = scan_code()
            if c then
                n = n + 1
                t[n] = utfchar(c)
            elseif scan_code(space_bits) then
                if n > 0 then
                    break
                end
            elseif n > 0 then
                break
            else
                return
            end
        end
        return concat(t,"",1,n)
    end

    -- so we gobble the space (like scan_int) (number has to be space or non-char terminated
    -- as we accept 0xabcd and such so there is no clear separator for a keyword

    scan_number = function(base)
        local n = 0
        while true do
            local c = scan_code()
            if c then
                n = n + 1
                t[n] = char(c)
            elseif scan_code(space_bits) then
                if n > 0 then
                    break
                end
            elseif n > 0 then
                break
            else
                return
            end
        end
        local s = concat(t,"",1,n)
        if base then
            return tonumber(s,base)
        else
            return tonumber(s)
        end
    end

end

-- -- the next one cannot handle \iftrue true\else false\fi
--
-- local function scan_boolean()
--     if scan_keyword("true") then
--         return true
--     elseif scan_keyword("false") then
--         return false
--     else
--         return nil
--     end
-- end

local function scan_boolean()
    local kw = scan_word()
    if kw == "true" then
        return true
    elseif kw == "false" then
        return false
    else
        return nil
    end
end

if not scan_csname then

    scan_csname = function()
        local t = get_next()
        local n = t.csname
        return n ~= "" and n or nil
    end

end

local function scan_verbatim()
    return scan_argument(false)
end

tokens.scanners = { -- these expand
    token     = scan_token,
    toks      = scan_toks,
    tokens    = scan_toks,
    dimen     = scan_dimen,
    dimension = scan_dimen,
    glue      = scan_glue,
    skip      = scan_glue,
    integer   = scan_int,
    real      = scan_real,
    float     = scan_float,
    count     = scan_int,
    string    = scan_string,
    argument  = scan_argument,
    tokenlist = scan_tokenlist,
    verbatim  = scan_verbatim,
    code      = scan_code,
    word      = scan_word,
    number    = scan_number,
    boolean   = scan_boolean,
    keyword   = scan_keyword,
    keywordcs = scan_keyword_cs,
    csname    = scan_csname,
}

tokens.getters = { -- these don't expand
    meaning = get_meaning,
    macro   = get_macro,
    token   = get_next,
    count   = tex.getcount,
    dimen   = tex.getdimen,
    skip    = tex.getglue,
    glue    = tex.getglue,
    skip    = tex.getmuglue,
    glue    = tex.getmuglue,
    box     = tex.getbox,
}

tokens.setters = {
    macro = set_macro,
    char  = set_char,
    lua   = set_lua,
    count = tex.setcount,
    dimen = tex.setdimen,
    skip  = tex.setglue,
    glue  = tex.setglue,
    skip  = tex.setmuglue,
    glue  = tex.setmuglue,
    box   = tex.setbox,
}

-- static int run_scan_token(lua_State * L)
-- {
--     saved_tex_scanner texstate;
--     save_tex_scanner(texstate);
--     get_x_token();
--     make_new_token(L, cur_cmd, cur_chr, cur_cs);
--     unsave_tex_scanner(texstate);
--     return 1;
-- }
--
-- static int run_get_future(lua_State * L)
-- {
--  /* saved_tex_scanner texstate; */
--  /* save_tex_scanner(texstate); */
--     get_token();
--     make_new_token(L, cur_cmd, cur_chr, cur_cs);
--     back_input();
--  /* unsave_tex_scanner(texstate); */
--     return 1;
-- }

if setinspector then

    local simple = { letter = "letter", other_char = "other" }

    local function astable(t)
        if t and is_token(t) then
            local cmdname = t.cmdname
            local simple  = simple[cmdname]
            if simple then
                return {
                    category   = simple,
                    character  = utfchar(t.mode) or nil,
                }
            else
                return {
                    command    = t.command,
                    id         = t.id,
                    tok        = t.tok,
                    csname     = t.csname,
                    active     = t.active,
                    expandable = t.expandable,
                    protected  = t.protected,
                    mode       = t.mode,
                    index      = t.index,
                    cmdname    = cmdname,
                }
            end
        end
    end

    tokens.astable = astable

    setinspector("token",function(v) local t = astable(v) if t then printtable(t,tostring(v)) return true end end)

end

tokens.cache = table.setmetatableindex(function(t,k)
    if not is_defined(k) then
        set_macro(k,"","global")
    end
    local v = create_token(k)
    t[k] = v
    return v
end)
