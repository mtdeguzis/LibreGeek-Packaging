#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-mpv.sh
# Script Ver:	  1.0.0
# Description:	Builds mpv for specific use in building PlexMediaPlayer
#
# See:		 
# Usage:        ./build-mpv.sh
# -------------------------------------------------------------------------------

#################################################
# VARS
#################################################

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
pkgname="mpv"
pkgver="${date_short}"
pkgrev="2"
pkgsuffix="git+bsos${pkgrev}"
dist_rel="brewmaster"
maintainer="ProfessorKaos64"
provides="mpv"
pkggroup="video"
requires=""
replaces=""

# build dirs
build_dir="/home/desktop/build-${pkgname}-temp"

# deps
# Use the build-wrapper instead of the main mpv source
# See: https://github.com/mpv-player/mpv/blob/master/README.md
git_url="https://github.com/mpv-player/mpv-build"
git_dir="mpv-build"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	
	# dependencies
	sudo apt-get install -y --force-yes build-essential git pkg-config samba-dev \
	luajit devscripts equivs ladspa-sdk libbluray-dev libbs2b-dev libcdio-paranoia-dev \
	libdvdnav-dev libdvdread-dev libenca-dev libfontconfig-dev libfribidi-dev libgme-dev \
	ibgnutls28-dev libgsm1-dev libguess-dev libharfbuzz-dev libjack-jackd2-dev libopenjpeg-dev \
	liblcms2-dev liblircclient-dev liblua5.2-dev libmodplug-dev libmp3lame-dev libopenal-dev \
	libopus-dev libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev librubberband-dev \
	libschroedinger-dev libsmbclient-dev libssh-dev libsoxr-dev libspeex-dev libtheora-dev \
	libtool libtwolame-dev libuchardet-dev libv4l-dev libva-dev libvdpau-dev libvorbis-dev \
	libvo-aacenc-dev libvo-amrwbenc-dev libvpx-dev libwavpack-dev libx264-dev libxvidcore-dev \
	python-docutils rst2pdf yasm

}

main()
{
	
	#################################################
	# Fetch source
	#################################################
	
	# create and enter build_dir
	if [[ -d "$build_dir" ]]; then
	
		sudo rm -rf "$build_dir"
		mkdir -p "$build_dir"
		
	else

		mkdir -p "$build_dir"
		
	fi
	
	# Enter build dir
	cd "$build_dir"

	#################################################
	# Build mpv-build deps pkg and install
	#################################################

	# clone
	git clone "$git_url" "$git_dir"
	
	# enter source dir
	cd "$git_dir"
	
	# check for updates
	./update
	
	# gather commits
	touch debian/changelog
	rm -f debian/changelog.TEMPLATE
	commits_full=$(git log --pretty=format:"  * %cd %h %s")
	
	# Create basic changelog format
	# This addons build cannot have a revision
	cat <<-EOF> changelog.in
	$pkgname (${pkgver}+${pkgsuffix}) $dist_rel; urgency=low
	
	  * Packaged deb for SteamOS-Tools
	  * See: packages.libregeek.org
	  * Upstream authors and source: $git_url
	  * ***** Full list of commits *****
	$commits_full
	 -- $uploader  $date_long

	EOF

	# Perform a little trickery to update existing changelog or create
	# basic file
	cat 'changelog.in' | cat - debian/changelog > temp && mv temp debian/changelog

	# open debian/changelog and update
	echo -e "\n==> Opening changelog for confirmation/changes."
	sleep 3s
	nano debian/changelog

 	# cleanup old files
 	rm -f changelog.in
 	rm -f debian/changelog.in
	
	# Install the dependencies 
	rm -f mpv-build-deps_*_*.deb
	sudo mk-build-deps
	
	echo -e "\n==> Building Debian package from source\n"
	sleep 2s
	
	# build debian package
	dpkg-buildpackage -uc -us
	
	#################################################
	# Cleanup
	#################################################
	
	# clean up dirs
	
	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"

	
	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)
	
	# back out of build temp to script dir if called from git clone
	if [[ "$scriptdir" != "" ]]; then
		cd "$scriptdir"
	else
		cd "$HOME"
	fi
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	echo -e "Showing contents of: ${build_dir}: \n"
	ls ${build_dir}| grep $pkgname_$pkgver

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# cut files
		if [[ -d "${build_dir}" ]]; then
			scp ${build_dir}/${pkgname}_${pkgver}* mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming
		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
install_prereqs
main
