# todo
#
# this script will replace mptopdf and makempy

puts("This program is yet unfinished, for the moment it just calls 'mptopdf'.\n\n")

system("texmfstart mptopdf #{ARGV.join(' ')}")
