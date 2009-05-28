if not modules then modules = { } end modules ['task-ini'] = {
    version   = 1.001,
    comment   = "companion to task-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a temporary solution, we need to isolate some modules and then
-- the load order can determine the trickery to be applied to node lists

tasks.appendaction("processors", "normalizers", "fonts.collections.process",    nil)
tasks.appendaction("processors", "normalizers", "fonts.checkers.missing",       nil)

tasks.appendaction("processors", "characters",  "chars.handle_mirroring",       nil, "notail")
tasks.appendaction("processors", "characters",  "chars.handle_casing",          nil, "notail")
tasks.appendaction("processors", "characters",  "chars.handle_breakpoints",     nil, "notail")
tasks.appendaction("processors", "characters",  "scripts.preprocess",           nil, "notail") -- this will be more generalized

tasks.appendaction("processors", "words",       "kernel.hyphenation",           nil)
tasks.appendaction("processors", "words",       "languages.words.check",        nil, "notail")

tasks.appendaction("processors", "fonts",       "nodes.process_characters",     nil, "notail")
tasks.appendaction("processors", "fonts",       "nodes.inject_kerns",           nil, "nohead")
tasks.appendaction("processors", "fonts",       "nodes.protect_glyphs",         nil, "nohead")
tasks.appendaction("processors", "fonts",       "kernel.ligaturing",            nil)
tasks.appendaction("processors", "fonts",       "kernel.kerning",               nil)

tasks.appendaction("processors", "lists",       "lists.handle_spacing",         nil, "notail")
tasks.appendaction("processors", "lists",       "lists.handle_kerning",         nil, "notail")

tasks.appendaction("shipouts",   "normalizers", "nodes.cleanup_page",           nil, "notail")

tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_color",        nil, "notail")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_transparency", nil, "notail")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_overprint",    nil, "notail")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_negative",     nil, "notail")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_effect",       nil, "notail")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_viewerlayer",  nil, "notail")

tasks.appendaction("math",       "normalizers", "noads.relocate_characters",    nil, "nohead")
tasks.appendaction("math",       "normalizers", "noads.resize_characters",      nil, "nohead")
tasks.appendaction("math",       "normalizers", "noads.respace_characters",     nil, "nohead")

tasks.appendaction("math",       "builders",    "noads.mlist_to_hlist",         nil, "notail")
