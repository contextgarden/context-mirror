#!/bin/sh

# Takes the same arguments as mtx-update

# you may change this if you want ...
CONTEXTROOT="$PWD/tex"

# suggested by Tobias Florek to check for ruby & rsync
if [ ! -x "`which rsync`" ]; then
	echo "You need to install rsync first."
	exit 1
fi
if [ ! -x "`which ruby`" ]; then
	echo "You might want to install Ruby first if you want to use pdfTeX or XeTeX."
fi

system=`uname -s`
cpu=`uname -m`

case "$system" in
	# linux
	Linux)
		case "$cpu" in
			i*86) platform="linux" ;;
			x86_64|ia64) platform="linux-64" ;;
			# a little bit of cheating with ppc64 (won't work on Gentoo)
			ppc|ppc64) platform="linux-ppc" ;;
			# we currently support just mipsel, but Debian is lying (reports mips64)
			# we need more hacks to fix the situation, this is just a temporary solution
			mips|mips64|mipsel|mips64el) platform="linux-mipsel" ;;
			*) platform="unknown" ;;
		esac ;;
	# Mac OS X
	Darwin)
		case "$cpu" in
			i*86) platform="osx-intel" ;;
			x86_64) platform="osx-64" ;;
			ppc*|powerpc|power*|Power*) platform="osx-ppc" ;;
			*) platform="unknown" ;;
		esac ;;
	# FreeBSD
	FreeBSD|freebsd)
		case "$cpu" in
			i*86) platform="freebsd" ;;
			x86_64) platform="freebsd" ;; # no special binaries are available yet
			amd64) platform="freebsd-amd64" ;;
			*) platform="unknown" ;;
		esac ;;
	# kFreeBSD (debian)
	GNU/kFreeBSD)
		case "$cpu" in
			i*86) platform="kfreebsd-i386" ;;
			x86_64|amd64) platform="kfreebsd-amd64" ;;
			*) platform="unknown" ;;
		esac ;;
	# cygwin
	CYGWIN*)
		case "$cpu" in
			i*86) platform="cygwin" ;;
			x86_64|ia64) platform="cygwin-64" ;;
			*) platform="unknown" ;;
		esac ;;
	# SunOS/Solaris
	SunOS)
		case "$cpu" in
			sparc) platform="solaris-sparc" ;;
			i86pc) platform="solaris-intel" ;;
			*) platform="unknown" ;;
		esac ;;
	*) platform="unknown"
esac

# temporary patch for 64-bit Leopard with 32-bit kernel
if test "$platform" = "osx-intel"; then
	# if running Snow Leopard or later
	# better: /usr/bin/sw_vers -productVersion
	if test `uname -r|cut -f1 -d"."` -ge 10 ; then
		# if working on 64-bit hardware
		if test `sysctl -n hw.cpu64bit_capable` = 1; then
			# snowleopard32=TRUE
			platform="osx-64"
		fi
	fi
fi

if test "$platform" = "unknown" ; then
	echo "Error: your system \"$system $cpu\" is not supported yet."
	echo "Please report to the ConTeXt mailing-list (ntg-context@ntg.nl)"
	exit
fi

# if you want to enforce some specific platform
# (when 'uname' doesn't agree with true architecture), uncomment and modify next line:
# platform=linux

# download or rsync the latest scripts first
rsync -rlptv rsync://contextgarden.net/minimals/setup/$platform/bin .

# download or update the distribution
# you may remove the --context=beta switch if you want to use "current"
# you can use --engine=luatex if you want just mkiv
env PATH="$PWD/bin:$CONTEXTROOT/texmf-$platform/bin:$PATH" \
mtxrun --script ./bin/mtx-update.lua --force --update --make --context=beta --platform=$platform --texroot="$CONTEXTROOT" $@

echo
echo "When you want to use context, you need to initialize the tree by typing:"
echo
echo "  . $CONTEXTROOT/setuptex"
echo
echo "in your shell or add"
echo "  \"$CONTEXTROOT/texmf-$platform/bin\""
echo "to PATH variable if you want to set it permanently."
echo "This can usually be done in .bashrc, .bash_profile"
echo "(or whatever file is used to initialize your shell)."
echo

if [ ! -x "`which ruby`" ]; then
	echo "You might want to install Ruby first if you want to use pdfTeX or XeTeX."
	echo
fi
