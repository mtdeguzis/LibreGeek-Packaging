#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-platform.sh
# Script Ver:	0.5.7
# Description:	Attmpts to build a deb package from platform git source
#
# See:		https://launchpadlibrarian.net/219136562/platform_2.19.3-1~vivid1.dsc
#
# Usage:	build-platform.sh [opts]
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

arg1="$1"
SCRIPTDIR=$(pwd)
TIME_START=$(date +%s)
TIME_STAMP_START=(`date +"%T"`)

# repo destinatin vars (use only local hosts!)

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming"
	
fi

# upstream URL
GIT_URL="https://github.com/Pulse-Eight/platform/"
branch="p8-platform-2.0.1"

# package vars
DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export STEAMOS_TOOLS_BETA_HOOK="false"
PKGNAME="p8-platform"
PKGVER="2.0.1"
PKGREV="2"
PKGSUFFIX="git+bsos${PKGREV}"
DIST="brewmaster"
URGENCY="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
MAINTAINER="ProfessorKaos64"

# set BUILD_TMP
export BUILD_TMP="${HOME}/build-${PKGNAME}-tmp"
SRCDIR="${PKGNAME}-${PKGVER}"
GIT_DIR="${BUILD_TMP}/${SRCDIR}"

install_prereqs()
{

	echo -e "\n==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config checkinstall bc python \
	cmake

}

main()
{
	
	# create BUILD_TMP
	if [[ -d "${BUILD_TMP}" ]]; then
	
		sudo rm -rf "${BUILD_TMP}"
		mkdir -p "${BUILD_TMP}"
		
	else
		
		mkdir -p "${BUILD_TMP}"
		
	fi

	# enter build dir
	cd "${BUILD_TMP}" || exit

	# install prereqs for build
	
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

	
	# Clone upstream source code
	
	echo -e "\n==> Obtaining upstream source code\n"

	git clone -b "${branch}" "${GIT_URL}" "${GIT_DIR}"
 
	#################################################
	# Build platform
	#################################################
	
	echo -e "\n==> Creating original tarball\n"
	sleep 2s
	
	# create source tarball
	cd "${BUILD_TMP}"
	tar -cvzf "${PKGNAME}_${PKGVER}.orig.tar.gz" "${SRCDIR}"
	
	# emter source dir
	cd "${SRCDIR}"

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${PKGVER}+${PKGSUFFIX}" --package "${PKGNAME}" -D "${DIST}" -u "${URGENCY}" \
		"Update to the latest release, $PKGVER"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${PKGVER}+${PKGSUFFIX}" --package "${PKGNAME}" -D "${DIST}" -u "${URGENCY}" \
		"Update to the latest release, $PKGVER"
		nano "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	# build
	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}
	
	#################################################
	# Cleanup
	#################################################
	
	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$TIME_START) / 60 " | bc)
	
	# output finish
	cat<<-EOF
	
	Time started: ${TIME_STAMP_START}
	echo -e "Time started: ${time_stamp_end}
	echo -e "Total Runtime (minutes): $runtime
	EOF
	
	# inform user of packages
	cat<<- EOF
	#################################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependency errors listed above.
	#################################################################

	EOF

	echo -e "Showing contents of: ${BUILD_TMP}: \n"
	ls "${BUILD_TMP}" | grep -E *${PKGVER}*

	# Ask to transfer files if debian binries are built
	# Exit out with log link to reivew if things fail.

	if [[ $(ls "${BUILD_TMP}" | grep -w "deb" | wc -l) -gt 0 ]]; then

		echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
		sleep 0.5s
		# capture command
		read -erp "Choice: " transfer_choice

		if [[ "$transfer_choice" == "y" ]]; then

			# copy files to remote server
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" \
			--filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_TMP}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# uplaod local repo changelog
			cp "${GIT_DIR}/debian/changelog" "${SCRIPTDIR}/debian"

		elif [[ "$transfer_choice" == "n" ]]; then
			echo -e "Upload not requested\n"
		fi

	else

		# Output log file to sprunge (pastebin) for review
		echo -e "\n==OH NO!==\nIt appears the build has failed. See below log file:"
		cat ${BUILD_TMP}/${PKGNAME}*.build | curl -F 'sprunge=<-' http://sprunge.us

	fi

}

# start main
main

