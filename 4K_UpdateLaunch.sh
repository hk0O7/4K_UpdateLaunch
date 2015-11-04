#!/bin/bash


installpath='/opt/4klauncher/4K_UpdateLaunch.sh'
desktoppath=""$HOME"/.local/share/applications/4K_UpdateLaunch.desktop"

function fn_error {
	local errormsg="$1"
	if [[ -n "$errormsg" ]]; then
		printf '\e[1;31mError\e[0m: '
		printf "$errormsg"
		printf '\n'
	fi
	read -n10 -t.1 # Ignore previous keypresses
	read -n1 -t5
	exit 1
}

function fn_ubuntucheck {
	if
		! which 'x-terminal-emulator' >/dev/null ||
		[[ ! -f '/usr/bin/apt-get' ]]
	then
		fn_error "4K Video Downloader is only available for Ubuntu-based distributions."
	fi
}

function fn_askuser {
	# Yes -> 0; No -> 1
	local question="$1"
	local defaultanswer="$2"
	local timeout="$3"
	local useranswer
	local timer="$timeout"
	read -n10 -t.1 # Ignore previous keypresses
	if [[ -n "$timeout" ]]; then printf '\e[s'; fi
	while [[ 1 ]]; do
		if [[ -n "$timeout" ]]; then printf '\e[u\e[K'; fi
		printf "$question"
		if [[ -n "$timeout" ]]; then printf " ("$timer")"; fi
		case "$defaultanswer" in
			[Yy] ) printf ' [Y/n] ';;
			[Nn] ) printf ' [y/N] ';;
			* ) printf ' [y/n] ';;
		esac
		if [[ -z "$timeout" ]]; then
			# Without timeout
			read -n1 useranswer
		else
			# With timeout
			if [[ "$timer" = '0' ]]; then
				printf '\n'
				case "$defaultanswer" in
					[Yy] ) return 0;;
					* ) return 1;;
				esac
			fi
			read -n1 -t1 useranswer || {
				((timer--))
				useranswer='NULL'
			}
		fi
		case "$useranswer" in
			[Yy] ) printf '\n'; return 0;;
			[Nn] ) printf '\n'; return 1;;
			'' )
				case "$defaultanswer" in
					[Yy] ) return 0;;
					[Nn] ) return 1;;
				esac
				;;
			'NULL' ) ;;
			* ) printf '\n';;
		esac
	done
}

function fn_printstep {
	if [[ "$printstep_newline" = '1' ]]; then
		printf '\n'
	else
		printstep_newline=1
	fi
	local stepmsg="$1"
	printf '\e[1;32m>>\e[0m '
	printf "$stepmsg"
	printf '\n'
}

### UNINSTALLATION
case "$1" in
	'uninstall'|'-uninstall'|'--uninstall' )
		# Check if already installed
		if ! [[ -f "$installpath" ]]; then
			fn_error "This script is not installed."
		fi
		if fn_askuser "Do you want to uninstall this script?" 'N'; then
			printstep_newline=1
			fn_printstep "Uninstalling "$(basename "$0")""
			sudo rm -rv "`dirname "$installpath"`" || fn_error
			printf "Removing '"$desktoppath"'\n"
			xdg-desktop-menu uninstall --mode user "$desktoppath" ||
			 rm -v "$desktoppath"
			printf "Script uninstalled.\n"
			# If 4K is installed, prompt to uninstall
			if {
				dpkg --get-selections 4kvideodownloader |
				  grep -qFw 'install'
			}; then
				if fn_askuser "Uninstall 4K Video Downloader?" 'Y'; then
					fn_printstep 'Uninstalling 4K Video Downloader...'
					sudo dpkg -r 4kvideodownloader ||
					 fn_error "Failed to uninstall 4K Video Downloader."
					printf "4K Video Downloader uninstalled.\n"
				else
					printf "Leaving 4K Video Downloader installed.\n"
				fi
			fi
			printf "\nAll done.\n"
			exit 0
		else
			printf "Aborted.\n"
			exit 0
		fi
		exit
		;;
	'' ) ;;
	* ) fn_error "Wrong argument."
esac

### VIRTUAL TERMINAL HANDLING
function fn_reruninxterm {
	local path
	if [[ -n "$1" ]]; then
		path="$1"
	else
		path="$0"
	fi
	setsid xterm \
	   -fn 9x15 \
	   -bg black -fg white \
	   -T '4k Download Updater' \
	   -e "$path" \
	&
	sleep 0.1
	exit 0
}
# If not in xterm
if [[ -z "$XTERM_VERSION" ]]; then
	# If xterm is present
	if which 'xterm' >/dev/null; then
		fn_reruninxterm
	# If xterm is not present, use generic terminal
	else
		fn_ubuntucheck
		# If not already in a graphical terminal
		if ! grep -Fq 'xterm' <<<"$TERM"; then
			# Generic name for Debian-based distros
			x-terminal-emulator -e "$0"
			exit 0
		fi
		# Recommend installing xterm
		printstep_newline=1
		printf "It is recommended to have xterm installed.\n"
		if fn_askuser "Install xterm?" 'N' '5'; then
			fn_printstep 'Installing xterm...'
			sudo apt-get -y install xterm
			apt_exitcode="$?"
			printf '\n'
			if [[ "$apt_exitcode" != '0' ]]; then
				fn_error "APT exited with status "$apt_exitcode""
			fi
			fn_reruninxterm
		fi
		printf '\n'
	fi
fi

fn_ubuntucheck

### SCRIPT INSTALLATION
# If not already installed, prompt to install.
if ! [[ -f "$installpath" ]]; then
	printstep_newline=1
	printf "This script is not installed. It is recommended to have it installed.\n"
	if fn_askuser "Install this script?" 'N'; then
		fn_printstep 'Installing script...'
		# Script
		if ! [[ -d "$(dirname "$installpath")" ]]; then
			sudo mkdir -pv "$(dirname "$installpath")" || fn_error
		fi
		sudo cp -v "$0" "$installpath" || fn_error
		sudo chmod -v 755 "$installpath" || fn_error
		# .desktop file
		if ! [[ -f "$desktoppath" ]]; then
			if ! [[ -d "$(dirname "$desktoppath")" ]]; then
				mkdir -pv "$(dirname "$desktoppath")" || fn_error
			fi
			cat >"$desktoppath" <<-EOF
				[Desktop Entry]
				Type=Application
				Terminal=false
				Exec="$installpath"
				Name=4K Updater/Launcher
				Comment=Update & Launch 4K Video Downloader
				Icon=4kvideodownloader.png
				Categories=Network;
			EOF
			if [[ "$?" != '0' ]]; then
				fn_error "Failed to write .desktop file."
			fi
			printf "Created '"$desktoppath"'\n"
#			desktop-file-install --dir="$(dirname "$desktoppath")" "$desktoppath"
			xdg-desktop-menu install --novendor --mode user "$desktoppath"
		fi
			printf "\nScript installed in "$installpath"\n"
			printf "You can now find it in your applications menu as '4K Updater/Launcher', under\n"
			printf "the 'Internet' (or 'Networking') section.\n"
			printf 'To uninstall it, open a terminal and type:\n'
			printf '\t$ /opt/4klauncher/4K_UpdateLaunch.sh uninstall\n'
			printf '\nPress a key to close the installer.\n'
			read -n10 -t.1
			read -n1
			#fn_reruninxterm "$installpath"
			exit 0
	else
		printf "Not installing; continuing...\n"
	fi
fi

### CURL CHECK
# If curl not present
if ! which 'curl' >/dev/null; then
	printstep_newline=1
	printf "Error: curl is not installed.\n"
	if fn_askuser "Install curl?" 'Y'; then
		fn_printstep 'Installing curl...'
		sudo apt-get -y install curl
		apt_exitcode="$?"
		if [[ "$apt_exitcode" != '0' ]]; then
			fn_error "APT exited with status "$apt_exitcode""
		fi
		printf "curl installed.\n"
	else
		printf "Aborted.\n"
		read -n1 -t2
		exit 1
	fi
fi

function fn_checkrun {
	# Returns 0 if 4K is running, 1 if not.
	ps x |
	  grep -Fw '/usr/lib/4kvideodownloader/4kvideodownloader-bin' |
	  grep -qFv 'grep'
}

### EXIT IF 4K IS RUNNING
if fn_checkrun; then
	fn_error '4K Video Downloader is already running.'
fi

function fn_launch {
	fn_printstep 'Launching 4kvideodownloader'
	setsid '4kvideodownloader' 2>/dev/null 1>&2 &
	until fn_checkrun; do
		sleep 0.1
		printf '.'
	done
	sleep 0.5
	exit 0
}

### MAIN CODE
cd ~/'Downloads/' 2>/dev/null ||
 eval "$(grep -E '^XDG_DOWNLOAD_DIR=' ""$HOME"/.config/user-dirs.dirs" 2>/dev/null)"
 if [[ -n "$XDG_DOWNLOAD_DIR" ]]; then
 	cd "$XDG_DOWNLOAD_DIR" 2>/dev/null ||
 	 cd "$HOME"
 else
 	cd "$HOME"
 fi

fn_printstep "Fetching latest version..."

# 32/64-bit detection
case `uname -m` in
	i[0-9]86 ) arch='x86' ;;
	'x86_64' ) arch='x86_64' ;;
	* ) fn_error "Architecture not detected.";;
esac
curl_useragent="Ubuntu Linux "$arch""

downloadpage="$(
	curl -s \
	   --user-agent "$curl_useragent" \
	   'https://www.4kdownload.com/?source=videodownloader'
)"

lastdeburl="$(
	grep -ow 'http://.*downloads\.4kdownload\.com/app/4kvideodownloader.*\.deb' <<<"$downloadpage" |
	  head -n1
)"

if [[ -z "$lastdeburl" ]]; then
	fn_error "Failed to retrieve information. Check your connection."
fi

lastdebfilename=`basename $lastdeburl`

if [[ "$arch" = 'x86_64' ]]; then arch='x64'
else arch='x86'
fi
lastdebversion=$(
	printf "$downloadpage" |
	  grep -Eo "'videodownloader_[[:digit:]]\.[[:digit:]]\.[[:digit:]]\.[[:digit:]]*_ubuntu_"$arch"'" |
	  head -n1 |
	  cut -d '_' -f2
)

# If 4K is installed
if [[ -f '/usr/lib/4kvideodownloader/4kvideodownloader-bin' ]]; then
	installedversion=$(
		grep -Eao '[[:digit:]]\.[[:digit:]]\.[[:digit:]]\.[[:digit:]]{4}' \
		   '/usr/lib/4kvideodownloader/4kvideodownloader-bin'
	)
else
	installedversion='NONE'
fi

printf "Latest version found: "$lastdebversion"\n"
printf "Installed version: "$installedversion"\n"

if [[ "$lastdebversion" == "$installedversion" ]]; then
	printf 'Up to date.\n'
	fn_launch
else
	killall "4kvideodownloader-bin" 2>/dev/null
fi

fn_printstep "Downloading the latest version..."
curl --progress-bar "$lastdeburl" -o "$lastdebfilename"
curl_exitcode="$?"
if [[ "$curl_exitcode" != '0' ]]; then
	fn_error "curl exited with status "$curl_exitcode""
fi

function fn_installdeb {
	sudo dpkg -i "$lastdebfilename" ||
	 fn_error "Installation failed. Check for permissions or broken packages."
}

fn_printstep "Installing latest package:"
fn_installdeb &&
printf "Installation complete. Latest version of 4kvideodownloader installed.\n"
fn_launch

