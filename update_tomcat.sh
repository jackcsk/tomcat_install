#!/usr/bin/env bash

CURL=$(which curl 2>/dev/null)
if [ -z "${CURL}" ]; then
	echo "ERROR: curl is not available"
	exit -1
fi

TOMCAT_URL=`${CURL} -s http://tomcat.apache.org/download-80.cgi | grep -Po "http.*[0-9]\.tar\.gz" | head -1`
START_SCRIPT_NAME=tomcat8
INSTALL_DIST=/usr/local/
INSTALL_DIST_SYMLINK=/usr/local/tomcat8
DIST_PATH=./dist
EXTRACTED_PATH=./extracted
LIB_PATH=./lib

cleanup() {
	rm "${DIST_PATH}/apache-tomcat*.tar.gz" 2>/dev/null
	rm -rf "./${EXTRACTED_PATH}"
}

distroName() {

	LSB_RELEASE=$(which lsb_release 2>/dev/null)
	[ -n "${LSB_RELEASE}" ] && [ -x "${LSB_RELEASE}" ] && OS=$(${LSB_RELEASE} -si)
	if [[ "${OS}" == *"Ubuntu"* ]]; then
		echo "ubuntu"
		return 0
	fi
	
	if [ -f /etc/redhat-release ]; then
		echo "redhat"
		return 0
	fi
	
	echo "unsupported"
	return -1
}

prep() {
	cleanup	

	[ ! -d "${DIST_PATH}" ] && mkdir -p "${DIST_PATH}"
	[ ! -d "${EXTRACTED_PATH}" ] && mkdir -p "${EXTRACTED_PATH}"
}

run() {
	(cd "${DIST_PATH}" && curl -O "${TOMCAT_URL}")
	tar -zxf ${DIST_PATH}/apache-tomcat*.tar.gz -C "${EXTRACTED_PATH}"
	
	if [ -d "${LIB_PATH}" ]; then
		cp -a ${LIB_PATH}/* ${EXTRACTED_PATH}/apache-tomcat*/lib/
	fi
	
	INSTALLED=`ls ${INSTALL_DIST} | grep apache-tomcat-8 | head -1`
	echo "INSTALL=${INSTALLED}"
	if [ -n "${INSTALLED}" ]; then
		echo "WARN: installed tomcat detected"
		echo "You may want to copy the files at ${EXTRACTED_DIR} over manually"
		exit 0
	fi
	
	[ -L "${INSTALL_DIST_SYMLINK}" ] && sudo rm ${INSTALL_DIST_SYMLINK}
	TOMCAT_VERSION=`cd ${EXTRACTED_PATH} && ls -d apache-tomcat*`
	sudo mv ${EXTRACTED_PATH}/${TOMCAT_VERSION} ${INSTALL_DIST} && sudo ln -s ${INSTALL_DIST}${TOMCAT_VERSION} ${INSTALL_DIST_SYMLINK}
}

DISTRO=$(distroName)
if [ "${DISTRO}" == "unsupported" ]; then
	echo "ERROR: distro is unsupported"
	exit -1
fi

prep
run

case "${DISTRO}" in
"ubuntu")
	sudo cp -a ./init.d/tomcat8-ubuntu /etc/init.d/${START_SCRIPT_NAME} && sudo chmod a+x /etc/init.d/${START_SCRIPT_NAME} && sudo chown root:root /etc/init.d/${START_SCRIPT_NAME}
	sudo /usr/sbin/update-rc.d -f ${START_SCRIPT_NAME} default
	sudo /usr/sbin/update-rc.d ${START_SCRIPT_NAME} enable
	;;
"redhat")
	sudo cp -a ./init.d/tomcat8-redhat /etc/init.d/${START_SCRIPT_NAME} && sudo chmod a+x /etc/init.d/${START_SCRIPT_NAME} && sudo chown root:root /etc/init.d/${START_SCRIPT_NAME}
	sudo /sbin/chkconfig --add ${START_SCRIPT_NAME}
	sudo /sbin/chkconfig ${START_SCRIPT_NAME} on
	;;
esac
