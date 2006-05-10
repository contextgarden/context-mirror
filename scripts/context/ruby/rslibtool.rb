# program   : rslibtool
# copyright : PRAGMA Publishing On Demand
# version   : 1.00 - 2002
# author    : Hans Hagen
#
# project   : eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-pod.com / www.pragma-ade.com

# --add      --base=filename --path=directory pattern
# --remove   --base=filename --path=directory label
# --sort     --base=filename --path=directory
# --purge    --base=filename --path=directory
# --dummy    --base=filename
# --namespace

# rewrite

unless defined? ownpath
    ownpath = $0.sub(/[\\\/]\w*?\.rb/i,'')
    $: << ownpath
end

require 'rslb/base'
require 'xmpl/base'
require 'xmpl/switch'

session = Example.new('rslbtool', '1.0', 'PRAGMA POD')

session.identify

commandline = CommandLine.new

commandline.registerflag('add')
commandline.registerflag('remove')
commandline.registerflag('delete')
commandline.registerflag('sort')
commandline.registerflag('purge')
commandline.registerflag('dummy')
commandline.registerflag('process')
commandline.registerflag('namespace')

commandline.registervalue('prefix')
commandline.registervalue('base')
commandline.registervalue('path')
commandline.registervalue('result')
commandline.registervalue('texexec')
commandline.registervalue('zipalso')

commandline.expand

session.inherit(commandline)

base = session.get('option.base')
path = session.get('option.path')

base = 'rslbtool.xml' if base.empty?

# when path is given, assume that arg list is list of
# suffixes, else assume it is a list of globbed filespec

if path.empty?
	base += '.xml' unless base =~ /\..+$/
	list = commandline.arguments
else
	Dir.chdir(File.dirname(path))
	list = Dir.glob("*.{#{commandline.arguments.join(',')}}")
end

begin
	reslib = Resource.new(base,session.get('option.namespace'))
	reslib.load(base)
rescue
	session.error('problems with loading base')
	exit
end

unless session.get('option.texexec').empty?
    reslib.set_texexec(session.get('option.texexec'))
end

if session.get('option.add')

	session.report('adding records', list)
	reslib.add_figures(list,session.get('option.prefix'))

elsif session.get('option.remove') or session.get('option.delete')

	session.report('removing records')
	reslib.delete_figures(list)

elsif session.get('option.sort')

	session.report('sorting records')
	reslib.sort_figures()

elsif session.get('option.purge')

	session.report('purging records')
	reslib.purge_figures()

elsif session.get('option.dummy')

	session.report('creating dummy records')
    reslib.create_dummies(session.get('option.process'),session.get('option.result'),session.get('option.zipalso'))

else

	session.warning('provide action')

end

reslib.save(base)
