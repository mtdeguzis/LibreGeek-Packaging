#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-ds4drv.sh
# Script Ver:	1.0.
# Description:	Attmpts to build a deb package from latest ds4drv
#		github release
#
# See:		https://github.com/chrippa/ds4drv
#
# Usage:	build-ds4drv.sh
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
# Check if USER/HOST is setup under ~/.bashrc, set to default if blank
# This keeps the IP of the remote VPS out of the build script

if [[ "${REMOTE_USER}" == "" || "${REMOTE_HOST}" == "" ]]; then

	# fallback to local repo pool TARGET(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi



if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming_testing"

else

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming"

fi

# upstream vars
# Ryochans fork is more up to date
# See: https://github.com/chrippa/ds4drv/pull/72#issuecomment-211043786

SRC_URL="https://github.com/chrippa/ds4drv"
#SRC_URL="https://github.com/Ryochan7/ds4drv"
TARGET="master"

# package vars
DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -nc"
export STEAMOS_TOOLS_BETA_HOOK="false"
export NO_LINTIAN="false"
export NO_PKG_TEST="false"
PKGNAME="ds4drv"
epoch="1"
PKGVER="0.5.1"
PKGSUFFIX="${DATE_SHORT}git+bsos"
BUILDER="pdebuild"
export STEAMOS_TOOLS_BETA_HOOK="false"
export NO_LINTIAN="false"
export NO_PKG_TEST="false"
PKGREV="1"
DIST="${DIST:=brewmaster}"
URGENCY="low"
UPLOADER="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
MAINTAINER="ProfessorKaos64"

# set BUILD_TMP
export BUILD_TMP="${HOME}/build-${PKGNAME}-tmp"
SRC_DIR="${BUILD_TMP}/${PKGNAME}-${PKGVER}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get -y --force-yes install autoconf automake build-essential pkg-config bc checkinstall \
	python-pip python python-setuptools python-dev python-pyudev bluez-tools gcc debhelper dh-systemd
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

	if [[ "${BUILDER}" != "pdebuild" && "${BUILDER}" != "sbuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	else

		# need cdbs before build for dh_clean
		sudo apt-get install -y --force-yes cdbs

	fi

	# Clone upstream source code and TARGET

	echo -e "\n==> Obtaining upstream source code\n"

	# clone
	git clone -b "${TARGET}" "${SRC_URL}" "${SRC_DIR}"

	#################################################
	# Build platform
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# Trim .git folders
	find "${SRC_DIR}" -name "*.git" -type d -exec sudo rm -r {} \;

	# create source tarball
	cd "${BUILD_TMP}"
	tar -cvzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" $(basename ${SRC_DIR})

	# copy in debian folder
	cp -r "${SCRIPTDIR}/ds4drv/debian" "${SRC_DIR}"

	# enter source dir
	cd "${SRC_DIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${epoch}:${PKGVER}+${PKGSUFFIX}-${PKGREV}" --package "${PKGNAME}" \
		-D "${DIST}" -u "${URGENCY}" "Update release"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${epoch}:${PKGVER}+${PKGSUFFIX}-${PKGREV}" --package "${PKGNAME}" \
		-D "${DIST}" -u "${URGENCY}" "Update release with Ryochan's updated fork"
		nano "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	#  build
	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

	#################################################
	# Cleanup
	#################################################

	# clean up dirs

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$TIME_START) / 60 " | bc)

	# output finish
	echo -e "\nTime started: ${TIME_STAMP_START}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"

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
			cp "${SRC_DIR}/debian/changelog" "${SCRIPTDIR}/ds4drv/debian"

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

