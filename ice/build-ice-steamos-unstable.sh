#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-ice.sh
# Script Ver:	1.3.5
# Description:	Builds simple pacakge for using ice based of of master upstream
#		git source
#
# See:		https://github.com/scottrice/Ice
#
# Usage:	./build-ice-steamos-unstable.sh
#
#-------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)

# upstream vars
git_url="https://github.com/scottrice/Ice"
rel_target="1.0.0"
commit="ae96fbd"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
pkgname="ice-steamos-unstable"
pkgver="1.0.0"
upstream_rev="1"
pkgrev="1"
pkgsuffix="${commit}+bsos${pkgrev}"
dist_rel="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build_dir
build_dir="$HOME/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s

	# Avoid libattr garbage for 32 bit package installed by emulators
	if [[ -f "/usr/share/doc/libattr1/changelog.Debian.gz" ]]; then

		sudo mv "/usr/share/doc/libattr1/changelog.Debian.gz" \
		"/usr/share/doc/libattr1/changelog.Debian.gz.old" 2> /dev/null
	fi

	# install basic build packages
	# Additional suggested packages added per: https://wiki.debian.org/Python/LibraryStyleGuide
	sudo apt-get install -y --force-yes build-essential bc debhelper \
	python-pip python-psutil groff git python-setuptools dh-python \
	python-all python-setuptools python-pip python-docutils python-sphinx \

	if [[ "$autobuild" != "yes" ]]; then

		# Only install if not doing an auto-build. Travis CI won't install this package
		sudo apt-get install -y --force-yes python-appdirs

	fi

}

main()
{

	# create build_dir
	if [[ -d "$build_dir" ]]; then

		sudo rm -rf "$build_dir"
		mkdir -p "$build_dir"

	else

		mkdir -p "$build_dir"

	fi

	# enter build dir
	cd "$build_dir" || exit

	# install prereqs for build
	install_prereqs

	echo -e "\n==> Obtaining upstream source code\n"

	# clone and checkout desired commit
	git clone -b "$rel_target" "$git_url" "${git_dir}"
	cd "${git_dir}"
	git checkout "$commit"

	# Add debian folder
	cp -r "$scriptdir/debian" "${git_dir}"

	# inject config files
	cp -r "$scriptdir/consoles.txt" "${git_dir}"
	cp -r "$scriptdir/emulators.txt" "${git_dir}"
	cp -r "$scriptdir/config.txt" "${git_dir}"

	# modify debian/control to reflect pkg name
        sed -ie "s|PKGNAME|$pkgname|g" "${git_dir}/debian/control"

	#################################################
	# Build package
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create the tarball from latest tarball creation script
	# use latest revision designated at the top of this script

	# create source tarball
	cd "${build_dir}"
	tar -cvzf "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz" "$pkgname"

	# Enter git dir to build
	cd "${git_dir}"

	# Create new changelog if we are not doing an autobuild
	# Also add exceptions for Travis CI build tests

	if [[ "$autobuild" != "yes" ]]; then

		cat <<-EOF> changelog.in
		$pkgname (${pkgver}+${pkgsuffix}-${upstream_rev}) $dist_rel; urgency=low

		  * Patched data paths for configuration files
		  * Latest "unstable" build against commit $commit
		  * Packaged deb for SteamOS-Tools
		  * See: packages.libregeek.org
		  * Upstream authors and source: $git_url

		 -- $uploader  $date_long

		EOF

		# Perform a little trickery to update existing changelog or create
		# basic file
		cat 'changelog.in' | cat - debian/changelog > temp && mv temp debian/changelog

		# open debian/changelog and update
		echo -e "\n==> Opening changelog for confirmation/changes."
		sleep 3s
		nano debian/changelog

	else

		# Add exceptions for travis ci build. python-appdirs is not yet whitelisted on travis ci
		# This is installed above manually via .travis.yml
		sed -ie '/python-appdirs/d' debian/control

	fi

 	# cleanup old files
 	rm -f changelog.in
 	rm -f debian/changelog.in

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	dpkg-buildpackage -rfakeroot -us -uc -sa

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
		cd "$scriptdir" || exit
	else
		cd "$HOME" || exit
	fi

	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"

	echo -e "Showing contents of: ${build_dir}: \n"
	ls ${build_dir}| grep ${pkgver}

	if [[ "$autobuild" != "yes" ]]; then

		echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
		sleep 0.5s
		# capture command
		read -erp "Choice: " transfer_choice

		if [[ "$transfer_choice" == "y" ]]; then

			# cut files
			if [[ -d "${build_dir}" ]]; then
				scp ${build_dir}/*${pkgver}* mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

			fi

		elif [[ "$transfer_choice" == "n" ]]; then
			echo -e "Upload not requested\n"
		fi
	fi

}

# start main
main
