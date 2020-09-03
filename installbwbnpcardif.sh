#!/bin/bash
#set -x
#-----------------------------------------
# Installation script BW 5 & 6(.x) for Linux/AIX
# Author : GERARD KOUASSI 
#-----------------------------------------

#-----------------------------------------------------
#		sub routines (associative array)
#----------------------------------------------------- 


#Helper function to check that file name contains a pattern
stringContains(){	
	local mystring=$1
	local search=$2
	[ $(expr $mystring : ".*${search}.*") -ne 0 ] && echo '1' ||  echo '0'	
}

trimStr(){
	local mystring=$1
	local result="$(echo -e "${mystring}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	echo "$result"
}

# put map
hput () {
  eval hash"$1"='$2'
}

# get map
hget () {
  eval echo '${hash'"$1"'#hash}'
}

# Test numeric chararacter
isNumeric () {
	case $1 in 
		*[!0-9]*) 
		echo 0;;		
		*)
		echo 1;;
	esac
}

#-----------------------------------------------------
#		function getNumVersion
#----------------------------------------------------- 
function getNumVersion
{
	local inputstr=$1
	local currentVersionStr=	
	typeset -i charIndex=1

	local nameLength=${#inputstr}
	while [ ${charIndex} -le ${nameLength} ];do
	   curChar=$(expr substr "$inputstr" ${charIndex} 1)			   
	   if [ $(isNumeric ${curChar}) -eq 1 ];then
	   	currentVersionStr=${currentVersionStr}${curChar}
	   fi
	   charIndex=charIndex+1
	done
	echo $currentVersionStr
}

#-----------------------------------------------------
#		function locateMaxVersion
#----------------------------------------------------- 
function locateMaxVersion
{	
	#$1 source dir
	#$2 test file
	local maxVersion
	local currentVersion	
	typeset -i maxVersion=0
	typeset -i currentVersion=0	
	typeset -i charIndex=0	
	
	#base
	local basedir=$1
	if [ ! -d $basedir ];then
	 	return 0
	fi
		
	for f in $(ls $basedir); do
		if [ -d $basedir/$f ] && [ ! -h $basedir/$f ];then
			if [ "$2" != "" ];then
				#test file
				if [ ! -f $basedir/$f/$2 ] && [ ! -d $basedir/$f/$2 ];then
					continue;
				fi
			fi
			
			local charIndex=1
			local currentVersionStr=
			local nameLength=${#f}
			while [ ${charIndex} -le ${nameLength} ];do
			   curChar=$(expr substr "$f" ${charIndex} 1)			   
			   if [ $(isNumeric ${curChar}) -eq 1 ];then
					if [ ${curChar} -ne 0 ];then
						currentVersionStr=${currentVersionStr}${curChar}
					elif [ ${#currentVersionStr} -gt 0 ];then
						currentVersionStr=${currentVersionStr}${curChar}
					fi
			   fi
			   charIndex=charIndex+1
			done
			currentVersion=${currentVersionStr}
			if [ ${currentVersion} -gt ${maxVersion} ];then
				maxVersion=$currentVersion
				hput $maxVersion "$f"
			fi			
		fi			
	done

	
	if [ $maxVersion -gt 0 ];then
		echo `hget $maxVersion`
	fi	
}



#-----------------------------------------------------
#		function copyVersion
#----------------------------------------------------- 
function copyVersion
{
	#$1 source dir
	#$2 target dir
	#$3 exclude
	for f in $(ls $1/*.jar); do
		if [ -f $f ];then
			local fiNameVersion=`basename $f`
			local fiName=${fiNameVersion%-*}
			fiName=${fiName%.*}
			if [ ! -z "$3" ];then
				local filtered=`echo $fiName | grep -E $3`
				if [ "${filtered}" != "" ];then
					continue
				fi
			fi
			if [ ! -f $2/${fiNameVersion} ];then
				echo "Updating $fiName on $2"
				rm -f $2/${fiName}-* 2>/dev/null
				cp -f ${f} $2/${fiNameVersion}
				if [ $? -ne 0 ];then
					echo "Problem during copy of ${f} to $2"
					return 2
				fi
			else
				local dupList=`ls $2/${fiName}-* 2>/dev/null`
				for fdup in ${dupList}; do
					#remove dups
					if [ "`basename ${fdup}`" != "${fiNameVersion}" ];then
						echo "removing duplicates ${fdup} on $2"
						rm -f ${fdup}
					fi
				done				
			fi
		fi
	done	
}

#-----------------------------------------------------
#		function removeVersion
#----------------------------------------------------- 
function removeVersion
{
	#$1 source dir
	#$2 target dir
	for f in $(ls $1/*); do
		if [ -f $f ];then
			local fiNameVersion=`basename $f`
			local fiName=${fiNameVersion%-*}
			fiName=${fiName%.*}						
#			echo "removing $fiName on $2"
			rm -f $2/${fiName}*							
		fi
	done
}

#-----------------------------------------------------
#		function echoNoNewLine
#----------------------------------------------------- 
function echoNoNewLine
{
	echo -n $1
}

#-----------------------------------------------------
#		showUsage routine
#-----------------------------------------------------
showUsage(){
	echo "---------------------------------------------------------------------------------------"
	echo "Incorrect parameters"
	echo "Usage : ${SCRIPTNAME} [TIBCO_ROOT] [BIN_HOME] [FILE_MAPPING] -force(optional) , where" 
	echo "TIBCO_ROOT        :Target TIBCO directory installation"
	echo "BIN_HOME          :Source directory containing installation files"
	echo "FILE_MAPPING      :Intall mapping file name under ${BIN_HOME}/common/fileInfos directory" 
	echo "-force            :force reinstall" 
	echo "---------------------------------------------------------------------------------------"
	exit $1
}


#-----------------------------------------------------
#		installArchive routine
#-----------------------------------------------------
installArchive(){	
	#set -x
	local extractedArchive=$1
	
	if [ ! -f ${extractedArchive} ];then
	  return 0
	fi	
	
	local archiveExtension=${extractedArchive##*.}
	local extractedArchiveDir=${extractedArchive%.*}
	
	echo
	echoNoNewLine "Processing ${extractedArchive}... "
	
	#remove last dot before gz
	if [ "${archiveExtension}" == "gz" ];then
		extractedArchiveDir=${extractedArchiveDir%.*}
	fi

	#Check already installed
	local extractedArchiveDirName=`basename ${extractedArchiveDir}`	
	local currentVersion=`cat ${INSTALL_MAPPING} | grep -wE ^${extractedArchiveDirName} | awk -F '=' 'NR==1 {print $2}'`
	if [ "${currentVersion}" == "" ];then
		echo "version not found for ${extractedArchiveDirName} on ${INSTALL_MAPPING}, skipping archive"
		cleanup ${extractedArchiveDir}
		return 0			
	fi
		
	#check force install
	if [ ${force} -eq 0 ];then
		echoNoNewLine "Checking ${currentVersion} existence..."
		if [ -f ${TIBCO_ROOT}/_installInfo/${currentVersion} ];then
			echo "${currentVersion} already installed"
			cleanup ${extractedArchiveDir}
			return 0
		elif [ -d ${TIBCO_ROOT}/${currentVersion} ];then
			echo "${TIBCO_ROOT}/${currentVersion} already installed"
			cleanup ${extractedArchiveDir}
			return 0
		elif  [ -f ${TIBCO_ROOT}/${currentVersion} ];then
			echo "${TIBCO_ROOT}/${currentVersion} already installed"
			cleanup ${extractedArchiveDir}
			return 0
		fi
	fi

	
	if [ "${archiveExtension}" == "zip" ];then			
		if [ ! -d ${extractedArchiveDir} ];then
			mkdir ${extractedArchiveDir}
			cd  ${extractedArchiveDir}
			unzip -q ${extractedArchive}
			if [ $? -ne 0 ];then
				echo "Error occured for ${extractedArchive}"
				cleanup ${extractedArchiveDir}
				return 2
			fi
		fi
		
		#get installer
		cd ${extractedArchiveDir}	

	elif [ "${archiveExtension}" == "gz" ];then
		if [ ! -d ${extractedArchiveDir} ];then
			mkdir ${extractedArchiveDir}
			cd  ${extractedArchiveDir}
			gzip -d ${extractedArchive}
			if [ $? -ne 0 ];then
				echo "Error occured for ${extractedArchive}"
				cleanup ${extractedArchiveDir}
				return 2
			fi
			tar xf ${extractedArchiveDir}.tar
			if [ $? -ne 0 ];then
				echo "Error occured for ${extractedArchive}"
				cleanup ${extractedArchiveDir}
				return 2
			fi
		fi
		
		#get installer
		cd ${extractedArchiveDir}	

	elif [ "${archiveExtension}" == "tar" ];then		
		if [ ! -d ${extractedArchiveDir} ];then
			mkdir ${extractedArchiveDir}
			cd  ${extractedArchiveDir}
			tar xf ${extractedArchive}
			if [ $? -ne 0 ];then
				echo "Error occured for ${extractedArchive}"
				cleanup ${extractedArchiveDir}
				return 2
			fi
		fi
		
		#get installer
		cd ${extractedArchiveDir}	
	
	elif [ "${archiveExtension}" == "bin" ];then
		
		#get installer
		cd `dirname ${extractedArchive}`

	else		
		echo "unknown file extension ${archiveExtension}, skipping archive $extractedArchive"
		return 0
	fi
		
	#Init switch var
	local isUniversalInstaller

	#the installer to use
	local usedInstaller
	
	if [ -d assemblies ] || [ -d licenses ];then	
		isUniversalInstaller=true	
		
		if [ -f ${TIBCO_INSTALLER} ];then
			chmod u+x ${TIBCO_INSTALLER}
			usedInstaller=${TIBCO_INSTALLER}

		elif [ -f ${TIBCO_INSTALLER_64} ];then
			chmod u+x ${TIBCO_INSTALLER_64}
			usedInstaller=${TIBCO_INSTALLER_64}

		elif [ -f ../${TIBCO_INSTALLER} ];then
			echo "Using  `pwd`../${TIBCO_INSTALLER}"
			cp ../${TIBCO_INSTALLER} .

			chmod u+x ${TIBCO_INSTALLER}
			usedInstaller=${TIBCO_INSTALLER}

		elif [ -f ../${TIBCO_INSTALLER_64} ];then
			echo "Using  `pwd`../${TIBCO_INSTALLER_64}"
			cp ../${TIBCO_INSTALLER_64} .

			chmod u+x ${TIBCO_INSTALLER_64}
			usedInstaller=${TIBCO_INSTALLER_64}


		elif [ -f ${TIBCO_ROOT}/tools/universal_installer/${TIBCO_INSTALLER} ];then	
			echo "Using  ${TIBCO_ROOT}/tools/universal_installer/${TIBCO_INSTALLER}"
			cp ${TIBCO_ROOT}/tools/universal_installer/${TIBCO_INSTALLER} .
			chmod u+x ${TIBCO_INSTALLER}
			usedInstaller=${TIBCO_INSTALLER}

		elif [ -f ${TIBCO_ROOT}/tools/universal_installer/${TIBCO_INSTALLER_64} ];then	
			echo "Using  ${TIBCO_ROOT}/tools/universal_installer/${TIBCO_INSTALLER_64}"
			cp ${TIBCO_ROOT}/tools/universal_installer/${TIBCO_INSTALLER_64} .
			chmod u+x ${TIBCO_INSTALLER_64}
			usedInstaller=${TIBCO_INSTALLER_64}

		else
			echo "Error occured for ${extractedArchive}, unable to find ${TIBCO_INSTALLER} or ${TIBCO_INSTALLER_64}"
			cleanup ${extractedArchiveDir}
			return 2
		fi				
		
		#option flag
		local optionflag=`cat ${INSTALL_MAPPING} | grep -wE ^${extractedArchiveDirName} | awk -F '=' 'NR==1 {print $3}'`
		echo $optionflag
	
	else
		local responseFile=`cat ${INSTALL_MAPPING} | grep -wE ^${extractedArchiveDirName} | awk -F '=' 'NR==1 {print $3}'`
		if [ "${responseFile}" == "" ];then
			echo "responseFile not found for ${extractedArchiveDirName} on ${INSTALL_MAPPING}, skipping installer"
			cleanup ${extractedArchiveDir}
			return 0
		fi
		
		local responseFileFullPath=${BIN_HOME}/common/responseFiles/${responseFile}
		if [ ! -f ${responseFileFullPath} ];then
			echo "responseFile not found for ${extractedArchiveDirName} at ${responseFileFullPath}, skipping installer"
			cleanup ${extractedArchiveDir}
			return 0
		fi				
		
		#find installer
		local nonUniversalInstaller
		if [ "${archiveExtension}" == "bin" ];then
			 nonUniversalInstaller=`basename ${extractedArchive}`
		else
			for f in $(\ls *.bin); do
				nonUniversalInstaller=$f
			done
		fi
		
		if [ "${nonUniversalInstaller}" == "" ];then
			echo "installer not found on ${extractedArchiveDirName}, skipping installer"
			cleanup ${extractedArchiveDir}
			return 0
		fi
		isUniversalInstaller=false
		chmod u+x ${nonUniversalInstaller}											
	fi
	
	
	replaceResponseFile ${extractedArchiveDir} ${responseFileFullPath}			
	if [ $? -ne 0 ];then
		echo "Error occured for ${extractedArchive}"
		cleanup ${extractedArchiveDir}
		return 2
	fi			

	#createTmpDir
	createTmpDir		
	
	#launch installer
	if [ "${isUniversalInstaller}" == "true" ];then		
		if [ "$optionflag" == "manual" ];then
			echo "launching TIBCOUniversalInstaller with option $optionflag"
			./${usedInstaller} -console -is:tempdir ${TMP_DIR}
			local returnStatus=$?
		else
			echo "launching TIBCOUniversalInstaller.."
			./${usedInstaller} -silent -is:tempdir ${TMP_DIR}
			local returnStatus=$?
		fi
		
		if [ ${returnStatus} -ne 0 ];then
	   		echo "error occurred during installation of ${extractedArchive}, installer exit code is ${returnStatus}"
	   		cleanup ${extractedArchiveDir}		
			return ${returnStatus}		
		fi

		if [ "$optionflag" == "nocheck" ];then
			echo ${currentVersion}>${TIBCO_ROOT}/_installInfo/${currentVersion}
		
		elif [ ! -f ${TIBCO_ROOT}/_installInfo/${currentVersion} ];then
			echo "error occurred during installation of ${extractedArchive}, ${TIBCO_ROOT}/_installInfo/${currentVersion} not found  after installation"
			cleanup ${extractedArchiveDir}		
			return 3
		fi
	else
		echo "launching ${nonUniversalInstaller} using responseFile ${responseFileFullPath}"
		./${nonUniversalInstaller} -options ${responseFileFullPath} -is:silent -silent -is:tempdir ${TMP_DIR}
		local returnStatus=$?
		if [ ${returnStatus} -ne 0 ];then
	   		echo "error occurred during installation of ${extractedArchive}, installer exit code is ${returnStatus}"
	   		cleanup ${extractedArchiveDir}		
			return ${returnStatus}		
		fi
		if [ ! -d ${TIBCO_ROOT}/${currentVersion} ] && [ ! -f ${TIBCO_ROOT}/${currentVersion} ];then
			echo "error occurred during installation of ${extractedArchive}, ${TIBCO_ROOT}/${currentVersion} not found  after installation"
			cleanup ${extractedArchiveDir}		
			return 3
		
		fi		
	fi
		
	echo "${extractedArchive} correctly installed"
	cleanup ${extractedArchiveDir}
}



#-----------------------------------------------------
#		jdbc drivers
#-----------------------------------------------------
installJdbcDrivers(){
	if [ ! -d ${BIN_HOME}/extensions/jdbc ];then
		return 0
	fi	
	echo
	echoNoNewLine "installing jdbc drivers... "	
	echo
	${BIN_HOME}/extensions/jdbc/install-bw6.sh ${TIBCO_ROOT}
	if [ $? -ne 0 ];then
		echo "Error occured during intallation of jdbc drivers"		
		return 2
	fi 		
	echo "OK"
}

#-----------------------------------------------------
#		ems drivers
#-----------------------------------------------------
installBWEMSDrivers(){

	#launch
	echo
	echoNoNewLine "Installing BW EMS Drivers..."
	
	local BW_EMSPLUGIN=${TIBCO_ROOT}/components/shared/1.0.0/plugins
	if [ ! -d "${BW_EMSPLUGIN}" ];then
		return 0
	fi
	
	#find bw		
	if [ ! -d "${TIBCO_ROOT}/bw" ];then
		return 0
	fi
		
	local BW_VERSION=$(locateMaxVersion "${TIBCO_ROOT}/bw" bin/bwcommon.tra)	
	if [ "${BW_VERSION}"  == "" ];then 
		return 0
	fi
	
	local BW_INSTALLEMS=${TIBCO_ROOT}/bw/${BW_VERSION}/config/drivers/shells/ems.runtime
	if [ ! -d "${BW_INSTALLEMS}" ];then
		return 0
	fi
	
	#Launch
	{
		cd "${TIBCO_ROOT}/bw/${BW_VERSION}/bin"
		"${TIBCO_ROOT}/bw/${BW_VERSION}/bin/bwinstall" ems-driver<<<"${BW_EMSPLUGIN}"
	} > /dev/null
	echo "OK"
}

#-----------------------------------------------------
#		bundle
#-----------------------------------------------------
installBundle(){
		
	local BUNDLE_DIR=${1}
	if [ ! -d "${BUNDLE_DIR}" ];then
		return 0
	fi
	
	local BW_VERSION=$(locateMaxVersion "${TIBCO_ROOT}/bw" bin/bwcommon.tra)	
	if [ "${BW_VERSION}"  == "" ];then 
		return 0
	fi
	
	#bw drs
	local TIBCO_BW_SYSTEM_SHARED_DIR=${TIBCO_ROOT}/bw/${BW_VERSION}/system/shared
	if [ ! -d ${TIBCO_BW_SYSTEM_SHARED_DIR} ];then
		echo "${TIBCO_BW_SYSTEM_SHARED_DIR} not found"
		return 1
	fi


	echo
	echo "installing bundles from ${BUNDLE_DIR} to ${TIBCO_BW_SYSTEM_SHARED_DIR}"	
	copyVersion "${BUNDLE_DIR}" "${TIBCO_BW_SYSTEM_SHARED_DIR}"
	if [ $? -ne 0 ];then
		echo "Problem during bundles installation"
		return 2
	fi
		
	echo "OK"
}


#-----------------------------------------------------
#		EMS 64
#-----------------------------------------------------
updateEMS64BitDaemon(){
	#find ems version
	local EMS_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/ems bin/tibemsd)		
	local TIBCO_EMS_DIR=
	if [ "${EMS_VERSION}" != "" ];then
		TIBCO_EMS_DIR=${TIBCO_ROOT}/ems/${EMS_VERSION}
	fi
	
	if [ -f ${TIBCO_EMS_DIR}/bin/tibemsd64 ];then
		#get existing link
		if [ ! -h ${TIBCO_EMS_DIR}/bin/tibemsd ];then
			echoNoNewLine "Creating link for ${TIBCO_EMS_DIR}/bin/tibemsd64.."
			mv ${TIBCO_EMS_DIR}/bin/tibemsd ${TIBCO_EMS_DIR}/bin/tibemsd32
			ln -s ${TIBCO_EMS_DIR}/bin/tibemsd64 ${TIBCO_EMS_DIR}/bin/tibemsd
			if [ $? -ne 0 ];then
				echo "Problem during create link"
				return 2
			else
				echo "OK"
			fi
		fi
	fi
	
	if [ -f ${TIBCO_EMS_DIR}/bin/tibemsadmin64 ];then
		#get existing link
		if [ ! -h ${TIBCO_EMS_DIR}/bin/tibemsadmin ];then
			echoNoNewLine "Creating link for ${TIBCO_EMS_DIR}/bin/tibemsadmin64.."
			mv ${TIBCO_EMS_DIR}/bin/tibemsadmin ${TIBCO_EMS_DIR}/bin/tibemsadmin32
			ln -s ${TIBCO_EMS_DIR}/bin/tibemsadmin64 ${TIBCO_EMS_DIR}/bin/tibemsadmin
			if [ $? -ne 0 ];then
				echo "Problem during create link"
				return 2
			else
				echo "OK"
			fi
		fi
	fi
}

#-----------------------------------------------------
#		RVD 64
#-----------------------------------------------------
updateRVD64BitDaemon(){
	#find ems version
	local RV_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/tibrv bin/rvd)		
	local TIBCO_RV_DIR=
	if [ "${RV_VERSION}" != "" ];then
		TIBCO_RV_DIR=${TIBCO_ROOT}/tibrv/${RV_VERSION}
	fi
	
	if [ -f ${TIBCO_RV_DIR}/bin/rvd64 ];then
		#get existing link
		if [ ! -h ${TIBCO_RV_DIR}/bin/rvd ];then
			echoNoNewLine "Creating link for ${TIBCO_RV_DIR}/bin/rvd64.."
			mv ${TIBCO_RV_DIR}/bin/rvd ${TIBCO_RV_DIR}/bin/rvd32
			ln -s ${TIBCO_RV_DIR}/bin/rvd64 ${TIBCO_RV_DIR}/bin/rvd
			if [ $? -ne 0 ];then
				echo "Problem during create link"
				return 2
			else
				echo "OK"
			fi
		fi
	fi
	
	if [ -f ${TIBCO_RV_DIR}/bin/rvrd64 ];then
		#get existing link
		if [ ! -h ${TIBCO_RV_DIR}/bin/rvrd ];then
			echoNoNewLine "Creating link for ${TIBCO_RV_DIR}/bin/rvrd64.."
			mv ${TIBCO_RV_DIR}/bin/rvrd ${TIBCO_RV_DIR}/bin/rvrd32
			ln -s ${TIBCO_RV_DIR}/bin/rvrd64 ${TIBCO_RV_DIR}/bin/rvrd
			if [ $? -ne 0 ];then
				echo "Problem during create link"
				return 2
			else
				echo "OK"
			fi
		fi
	fi
	
}

#-----------------------------------------------------
#		install simple hotfix routine
#-----------------------------------------------------
installSimpleHotFix(){
	#set -x
	local fixFile=$1
	local fixFileVersion=`basename ${fixFile%.*}`	
	local fixFileExtension=${fixFile##*.}
	
	echo
	echoNoNewLine "Processing ${fixFile}... "
	
	#Ungzip
	if [ "${fixFileExtension}" == "gz" ];then
		cd  `dirname ${fixFile}`
		gzip -d `basename ${fixFile}`
		if [ $? -ne 0 ];then
			echo "Error occured on gzip for ${fixFile}"
			return 2
		fi
		fixFile=${fixFile%.*}
		fixFileVersion=`basename ${fixFile%.*}`	
		fixFileExtension=${fixFile##*.}
	fi
		
	#Check already installed	
	local fixFileCheck=`cat ${INSTALL_MAPPING} | grep -wE ^${fixFileVersion} | awk -F '=' 'NR==1 {print $2}'`
	if [ "${fixFileCheck}" == "" ];then
		echo "version not found for ${fixFileVersion} on ${INSTALL_MAPPING}, skipping archive"		
		return 0
	fi
	
	local fixDir=`cat ${INSTALL_MAPPING} | grep -wE ^${fixFileVersion} | awk -F '=' 'NR==1 {print $3}'`
	if [ "${fixDir}" == "" ];then		
		fixDir=${TIBCO_ROOT}
	else
		fixDir=${TIBCO_ROOT}/${fixDir}
	fi
	
	if [ -f ${TIBCO_ROOT}/${fixFileCheck} ];then
		echo "${fixFileVersion} already installed"		
		return 0	
	fi
	
	if [ ! -d ${fixDir} ];then
		echo "${fixDir} not exists, ${fixFileVersion} cannot be installed"				
		return 2	
	fi
	
	if [ "${fixFileExtension}" == "zip" ];then
		echo "unzipping ${fixFileVersion} to ${fixDir}"	
		unzip -qn -d ${fixDir} ${fixFile}
		if [ $? -ne 0 ];then
			return 2
		fi
	elif  [ "${fixFileExtension}" == "tar" ];then
		cd ${fixDir}
		tar -xf ${fixFile}
		if [ $? -ne 0 ];then
			return 2
		fi
	
	else
		echo "Unknown file extendsion : ${fixFileExtension}, ${fixFileVersion} cannot be installed"				
		return 0
	fi
	
	echo "${fixFileVersion} correctly installed"	
}

#-----------------------------------------------------
#		replaceResponseFile routine
#-----------------------------------------------------
replaceResponseFile(){				
	readInstallInfos
	if [ $? -ne 0 ];then
		return 2
	fi

	#cd to archive dir if exists				
	if [ -d ${1} ];then  	
		cd  ${1}
	fi
	
	local localDir=$(basename $1)
	
	local pattern1="<entry key=\"installationRoot\">.*</entry>"
	local replacement1="<entry key=\"installationRoot\">${TIBCO_ROOT}</entry>"		
	local pattern2="<entry key=\"createNewEnvironment\">.*</entry>"
	local replacement2="<entry key=\"createNewEnvironment\">${TIBCO_CREATE_NEW_ENV}</entry>"
	local pattern3="<entry key=\"environmentName\">.*</entry>"
	local replacement3="<entry key=\"environmentName\">${TIBCO_ENVNAME}</entry>"	
	local pattern4="<entry key=\"configDirectoryRoot\">.*</entry>"
	local replacement4="<entry key=\"configDirectoryRoot\">${TIBCO_CONFIG_ROOT_DIR}</entry>"	
	local pattern5="<entry key=\"configFile\">.*</entry>"
	local replacement5="<entry key=\"configFile\">${TIBCO_EMS_CONFIG_FILE}</entry>"
	local pattern6="<entry key=\"adas400.jt400.dir\">.*</entry>"
	local replacement6="<entry key=\"adas400.jt400.dir\">${TIBCO_ROOT}/tpcl/${TPCL_VERSION}</entry>"
	
	#EMS for TRA 5.9		
	local EMS_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/ems bin/tibemsd)
	local pattern7="<entry key=\"emsConfigDir\">.*</entry>"
	local replacement7="<entry key=\"emsConfigDir\">${TIBCO_ROOT}/ems/${EMS_VERSION}</entry>"

	#for TEA (java)
	local pattern8="<entry key=\"DUMMY\">.*</entry>"
	local replacement8="<entry key=\"DUMMY\"></entry>"
	locateJavas
	if [ $? -eq 0 ] && [ ! -z ${TIB_JAVA_HOME} ];then
		local pattern8="<entry key=\"java.home.directory\">.*</entry>"
		local replacement8="<entry key=\"java.home.directory\">${TIB_JAVA_HOME}</entry>"						
	fi
	
	#for BW6 runtime or bw plugins
	if [ $(stringContains "${localDir}" "_BW_") -eq 1 ] || [ $(stringContains "${localDir}" "_bw") -eq 1 ];then
		local isRuntime="Runtime"	
		local pattern9="<entry key=\"selectedProfiles\">.*</entry>"	
		local replacement9="<entry key=\"selectedProfiles\">${isRuntime}</entry>"				
	else
		local pattern9="<entry key=\"DUMMY\">.*</entry>"
		local replacement9="<entry key=\"DUMMY\"></entry>"
	fi	
	
	#for BW6 LGPL
	local pattern10="<entry key=\"LGPLAssemblyDownload\">.*</entry>"	
	local replacement10="<entry key=\"LGPLAssemblyDownload\">false</entry>"
	local pattern11="<entry key=\"LGPLAssemblyPath\">.*</entry>"	
	local replacement11="<entry key=\"LGPLAssemblyPath\">${LGPLAssemblyPath}</entry>"		
	
	#for BW6 Oracle E-Business Plugin
	local pattern12="<entry key=\"oracle.jdbc.driver\"></entry>"
	local replacement12="<entry key=\"oracle.jdbc.driver\">${ThirdPartiesPath}/ojdbc6.jar</entry>"
	local pattern13="<entry key=\"oracle.aq.api\"></entry>"
	local replacement13="<entry key=\"oracle.aq.api\">${ThirdPartiesPath}/aqapi.jar</entry>"
	
	#for BW6 commented Home
	local pattern14="<!--entry key=\"environmentName\">.*</entry-->"
	
	for f in $(\ls *.silent); do
		local silentFile=${f}		
		local tmpfile=${f}.tmp				
		
		cat ${f} | sed -e s%"${pattern1}"%"${replacement1}"%g \
			| sed -e s%"${pattern2}"%"${replacement2}"%g \
			| sed -e s%"${pattern14}"%"${replacement3}"%g \
			| sed -e s%"${pattern3}"%"${replacement3}"%g \
			| sed -e s%"${pattern4}"%"${replacement4}"%g \
			| sed -e s%"${pattern5}"%"${replacement5}"%g \
			| sed -e s%"${pattern6}"%"${replacement6}"%g \
			| sed -e s%"${pattern7}"%"${replacement7}"%g \
			| sed -e s%"${pattern8}"%"${replacement8}"%g \
			| sed -e s%"${pattern9}"%"${replacement9}"%g \
			| sed -e s%"${pattern10}"%"${replacement10}"%g \
			| sed -e s%"${pattern11}"%"${replacement11}"%g \
			| sed -e s%"${pattern12}"%"${replacement12}"%g \
			| sed -e s%"${pattern13}"%"${replacement13}"%g > ${tmpfile}
		if [ $? -ne 0 ];then
			echo "Problem during silent file replacement"
			return 2
		fi
		break
	done	
	if [ "${silentFile}" == "" ];then
		echo "silent file not found"
		return 1
	else
		mv ${tmpfile} ${silentFile}
		if [ $? -ne 0 ];then
			echo "silent file ${silentFile} cannot be copied"
			return 2
		fi
	fi
	
}

#-----------------------------------------------------
#		createTmpDir routine
#----------------------------------------------------- 
createTmpDir(){
	if [ -d ${TMP_DIR} ];then
		rm -Rf ${TMP_DIR}
	fi
	mkdir -p  ${TMP_DIR}
}

#-----------------------------------------------------
#		cleanup routine
#----------------------------------------------------- 
cleanup(){
	cd ${CURRENT_DIR}
	if [ -d ${TMP_DIR} ];then
		rm -Rf ${TMP_DIR}
	fi
	
	if [ "$1" != "" ] && [ -d $1 ];then
		rm -Rf ${1}
	fi
}

#-----------------------------------------------------
#		readInstallInfos routine
#----------------------------------------------------- 
readInstallInfos(){	
	if [ -f ${TIBCO_ENV_INFOS} ];then		
		if [ -x "$(command -v xmllint)" ];then
			echoNoNewLine "Reading TIBCO_ENV_INFOS '${TIBCO_ENV_INFOS}' using xmllint..."
			local TIBCO_ENVNAME_TMP=$(xmllint --shell "${TIBCO_ENV_INFOS}" <<< \
			"xpath string(TIBCOEnvironment/environment[@location=\"${TIBCO_ROOT}\"]/@name)" | awk -F ':' '{print $NF}')							
			TIBCO_ENVNAME_TMP=$(trimStr $TIBCO_ENVNAME_TMP)
		 
			#local TIBCO_ENVNAME_TMP=$(xmllint --xpath "TIBCOEnvironment/environment[@location=\"${TIBCO_ROOT}\"]/@name" \
# 						"${TIBCO_ENV_INFOS}" | awk -F '=' '{print $2}' | sed 's/[\"]//g')
			
			if [ ! -z ${TIBCO_ENVNAME_TMP} ];then
				TIBCO_CREATE_NEW_ENV=false
				TIBCO_ENVNAME=${TIBCO_ENVNAME_TMP}
			fi

			#local TIBCO_CONFDIR_TMP=$(xmllint --xpath "TIBCOEnvironment/environment[@location=\"${TIBCO_ROOT}\"]/@configDir" \
#						 "${TIBCO_ENV_INFOS}" | awk -F '=' '{print $2}' | sed 's/[\"]//g')
						 
						 
			local TIBCO_CONFDIR_TMP=$(xmllint --shell "${TIBCO_ENV_INFOS}" <<< \
			 "xpath string(TIBCOEnvironment/environment[@location=\"${TIBCO_ROOT}\"]/@configDir)" | awk -F ':' '{print $NF}')							
			TIBCO_CONFDIR_TMP=$(trimStr $TIBCO_CONFDIR_TMP)		 		 
			if [ ! -z ${TIBCO_CONFDIR_TMP} ];then
				TIBCO_CONFIG_DIR=${TIBCO_CONFDIR_TMP}
			fi
			
		else			
			echoNoNewLine "Reading TIBCO_ENV_INFOS : '${TIBCO_ENV_INFOS}' using grep (xmllint not found)..."
			local TIBCO_ENVNAME_TMP=`grep name ${TIBCO_ENV_INFOS} | awk -F '=' '{print $2}'`
			TIBCO_ENVNAME_TMP=$(echo $TIBCO_ENVNAME_TMP | sed 's/[\"]//g')		
			if [ "${TIBCO_ENVNAME_TMP}" != "" ];then
				TIBCO_CREATE_NEW_ENV=false
				TIBCO_ENVNAME=${TIBCO_ENVNAME_TMP}
			fi
		 		
			local TIBCO_CONFDIR_TMP=`grep configDir ${TIBCO_ENV_INFOS} | awk -F '=' '{print $2}'`
			TIBCO_CONFDIR_TMP=$(echo $TIBCO_CONFDIR_TMP | sed 's/[\"]//g')
			if [ "${TIBCO_CONFDIR_TMP}" != "" ];then
				TIBCO_CONFIG_DIR=${TIBCO_CONFDIR_TMP}
			fi
		fi
	fi	
	
	#Resolve default (subject of changes)
	TIBCO_EMS_CONFIG_DIR=${TIBCO_CONFIG_DIR}/cfgmgmt/ems/data
	TIBCO_EMS_CONFIG_FILE=${TIBCO_EMS_CONFIG_DIR}/tibemsd.conf
	echo "found TIBCO_CONFIG_DIR='${TIBCO_CONFIG_DIR}', TIBCO_ENVNAME='${TIBCO_ENVNAME}'"
}


#-----------------------------------------------------
#		locateJavas routine
#----------------------------------------------------- 
locateJavas(){
	
	#IF java home is set on shell environement
	if [ ! -z ${JAVA_HOME} ];then
		TIB_JAVA_HOME=${JAVA_HOME}
		echo "found JAVA_HOME set by shell environement : ${TIB_JAVA_HOME}"
		return 0
	fi

	#find java version thru tra or bw		
	if [ ! -d ${TIBCO_ROOT}/bw ];then
		echo "BW not found"
		return 2
	fi
		
	local BW_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/bw bin/bwcommon.tra)
	
	if [ "${BW_VERSION}"  == "" ];then 
		echo "unable to locate JAVA, because BW_VERSION not found"
		return 2
	fi
	
	
	if [ "${BW_VERSION}" != "" ];then		
		local tibco_bw_dir=${TIBCO_ROOT}/bw/${BW_VERSION}
		local tibco_bw_bin_dir=${tibco_bw_dir}/bin
		local tibco_bw_tra=${tibco_bw_bin_dir}/bwcommon.tra
		
		TIB_JAVA_HOME=$(cat ${tibco_bw_tra} | grep TIBCO_JAVA_HOME | awk -F '=' 'NR==1 {print $2}')		
		JVM_LIB_DIR=$(cat ${tibco_bw_tra} | grep JVM_LIB_DIR | awk -F '=' 'NR==1 {print $2}')
		JVM_LIB_SERVER_DIR=$(cat ${tibco_bw_tra} | grep JVM_LIB_SERVER_DIR | awk -F '=' 'NR==1 {print $2}')
		
		#Trim values
		TIB_JAVA_HOME=$(trimStr "$TIB_JAVA_HOME")
		JVM_LIB_DIR=$(trimStr "$JVM_LIB_DIR")
		JVM_LIB_SERVER_DIR=$(trimStr "$JVM_LIB_SERVER_DIR")

		if [ "${TIB_JAVA_HOME}"  != "" ];then
			echo "found JAVA_HOME on ${tibco_bw_tra} : ${TIB_JAVA_HOME}"
		fi		
	fi
	
	if [ "${TIB_JAVA_HOME}"  == "" ];then
		echo "unable to locate JAVA_HOME on TRA or BW tra files"
		return 2
	fi		
	
}

#-----------------------------------------------------
#		create install file routine
#----------------------------------------------------- 
createInstallFile(){	
	echo
	echoNoNewLine "creating installation file ..."
	
	readInstallInfos 
	if [ $? -ne 0 ];then
		return 2
	fi

	#find tea version
	local TEA_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/tea bin/tea)		
	local TIBCO_TEA_DIR=
	if [ "${TEA_VERSION}" != "" ];then
		TIBCO_TEA_DIR=${TIBCO_ROOT}/tea/${TEA_VERSION}
	fi

	#find tea-ems-agent version
	local TEA_EMS_AGENT_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/tea/agents/ems bin/ems-agent)		
	local TIBCO_TEA_EMS_AGENT_DIR=
	if [ "${TEA_EMS_AGENT_VERSION}" != "" ];then
		TIBCO_TEA_EMS_AGENT_DIR=${TIBCO_ROOT}/tea/agents/ems/${TEA_EMS_AGENT_VERSION}
	fi
	
	#find ems version
	local EMS_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/ems bin/tibemsd)		
	local TIBCO_EMS_DIR=
	if [ "${EMS_VERSION}" != "" ];then
		TIBCO_EMS_DIR=${TIBCO_ROOT}/ems/${EMS_VERSION}
	fi
	
	#find bw version
	local BW_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/bw system)
	local TIBCO_BW_DIR=
	if [ "${BW_VERSION}"  != "" ];then 
		TIBCO_BW_DIR=${TIBCO_ROOT}/bw/${BW_VERSION}
	fi
	
	#find jdbc dir
	local TIBCO_BW_SYSTEM_DIR=${TIBCO_ROOT}/bw/${BW_VERSION}/system
	local TIBCO_BW_SYSTEM_LIB_DIR=${TIBCO_BW_SYSTEM_DIR}/lib	
		
	#find hawk version
	local HAWK_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/hawk bin/tibhawkhma)	
	local TIBCO_HAWK_DIR=
	local TIBCO_HAWK_CONFIG_DIR=
	local TIBCO_HAWK_TEA_AGENT_DIR=
	if [ "${HAWK_VERSION}" != "" ];then
		TIBCO_HAWK_DIR=${TIBCO_ROOT}/hawk/${HAWK_VERSION}
		TIBCO_HAWK_CONFIG_DIR=${TIBCO_CONFIG_DIR}/cfgmgmt/hawk
		TIBCO_HAWK_TEA_AGENT_DIR=${TIBCO_ROOT}/tea/agents/hawk/${HAWK_VERSION}
	fi


	#find rv version
	local TIBRV_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/tibrv bin/rvd)	
	local TIBCO_RV_DIR=
	if [ "${TIBRV_VERSION}" != "" ];then
		TIBCO_RV_DIR=${TIBCO_ROOT}/tibrv/${TIBRV_VERSION}
	fi
	
		
	#find bc version
	local BC_ENGINE_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/bc bin/bcengine)
	local TIBCO_BC_ENGINE_DIR=
	if [ "${BC_ENGINE_VERSION}" != "" ];then
		TIBCO_BC_ENGINE_DIR=${TIBCO_ROOT}/bc/${BC_ENGINE_VERSION}
	fi
	
	#find as version
	local TIBCO_AS_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/as lib/as-common.jar)	
	local TIBCO_AS_DIR=
	if [ "${TIBCO_AS_VERSION}" != "" ];then
		TIBCO_AS_DIR=${TIBCO_ROOT}/as/${TIBCO_AS_VERSION}
	fi
	 		
			
		
	locateJavas
	if [ $? -ne 0 ];then
		return 2
	fi

	#get existing link
	if [ -h ${installFile} ];then
		if [ "`uname`" != "AIX" ];then
			realinstallFile=`readlink ${installFile}`
		else 
			realinstallFile=`ls -l ${installFile} | awk '{print $11}'`
		fi		
	else
		realinstallFile=${installFile}
	fi
	
	echo "${realinstallFile}"
	
	if [ -f ${realinstallFile} ];then
		chmod u+w ${realinstallFile}
	fi

	echo "#---------------------------" > ${realinstallFile}
	echo "# `date`" >>  ${realinstallFile}
	echo "#---------------------------" >>  ${realinstallFile}
	

	writeToInstallFile "TIBCO_ROOT" "${TIBCO_ROOT}" ${realinstallFile}
	writeToInstallFile "TIBCO_TEA_DIR" "${TIBCO_TEA_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_TEA_EMS_AGENT_DIR" "${TIBCO_TEA_EMS_AGENT_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_EMS_DIR" "${TIBCO_EMS_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_CONFIG_DIR" "${TIBCO_CONFIG_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_EMS_CONFIG_DIR" "${TIBCO_EMS_CONFIG_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_EMS_CONFIG_FILE" "${TIBCO_EMS_CONFIG_FILE}" ${realinstallFile}	
	writeToInstallFile "TIBCO_ADMIN_DIR" "${TIBCO_ADMIN_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_BW_DIR" "${TIBCO_BW_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_BW_SYSTEM_LIB_DIR" "${TIBCO_BW_SYSTEM_LIB_DIR}" ${realinstallFile}
	#backward compat for scripts
	writeToInstallFile "TIBCO_TPCL_JDBC_DIR" "${TIBCO_BW_SYSTEM_LIB_DIR}" ${realinstallFile}
	
	
	#Com
	writeToInstallFile "TIBCO_HAWK_DIR" "${TIBCO_HAWK_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_HAWK_CONFIG_DIR" "${TIBCO_HAWK_CONFIG_DIR}" ${realinstallFile}
	writeToInstallFile "TIBCO_HAWK_TEA_AGENT_DIR" "${TIBCO_HAWK_TEA_AGENT_DIR}" ${realinstallFile}

	writeToInstallFile "AS_HOME" "${TIBCO_AS_DIR}" ${realinstallFile}	
	writeToInstallFile "TIBCO_RV_DIR" "${TIBCO_RV_DIR}" ${realinstallFile}
	
	#make it executable
	chmod ug+rx ${realinstallFile}
	
	#make it not modifiable
	chmod ugo-w ${realinstallFile}

	#Verify result
	echo
	while read line; do echo "$line";done < ${installFile}
	
	echo
	echo "installation file creation is OK"
}

#-----------------------------------------------------
#		write to install file routine
#----------------------------------------------------- 
writeToInstallFile(){		
	local key=${1}
	local value=${2}
	local vfile=${3}
	local nocheck=${4}
	
	if [ "${value}" == "" ];then 
		return 0;
	fi
	
	if [ -d "${value}" ] || [ -f "${value}" ] || [ ! -z ${nocheck} ];then
		echo "${key}=${value}" >> ${vfile} 
	fi	
}

#-----------------------------------------------------
#		Main routine
#-----------------------------------------------------
#Resolve links
if [ -h $0 ] && [ "`uname`" != "AIX" ];then
	prg=`readlink $0`
elif [ -h $0 ] && [ "`uname`" == "AIX" ];then
	prg=`ls -l $0 | awk '{print $11}'`
else
	prg=$0
fi

CURRENT_DIR=`pwd -P`
CURRENT_DIR=`cd ${CURRENT_DIR}; pwd -P`
SCRIPTDIR=`dirname $prg`
SCRIPTDIR=`cd ${SCRIPTDIR}; pwd -P`
SCRIPTNAME=`basename $prg`
SCRIPT_HOME=`cd ${SCRIPTDIR}; pwd -P`
HOME_DIR=${HOME}

nbparam=$#
typeset -i iparm=1

#Controle param
if [ ${nbparam} -lt 3 ];then
	showUsage 1
fi

while [ $iparm -le ${nbparam} ];do
	if [ $iparm -eq 1 ];then
		TIBCO_ROOT=`dirname $1`/`basename $1`
		shift
	elif [ $iparm -eq 2 ];then
		BIN_HOME=$1
		BIN_HOME=`cd ${BIN_HOME}; pwd -P`
		shift
	elif [ $iparm -eq 3 ];then
		INSTALL_MAPPING=${BIN_HOME}/common/fileInfos/${1}
		shift
	elif [ "$1" = "-force" ];then
		forceArg=$1
		shift	
	fi
	iparm=$iparm+1
done

#Remove unnecessary chars
mkdir -p ${TIBCO_ROOT}
if [ ! -d ${TIBCO_ROOT} ];then
	echo "Unable to create ${TIBCO_ROOT} or directory not found"
	return 2
fi

#BIN HOME
if [ ! -d ${BIN_HOME} ];then
	echo "binaries not found at ${BIN_HOME}"
	showUsage 1
fi
#Resolve full path
BIN_HOME=`cd ${BIN_HOME}; pwd -P`

#INSTALL_MAPPING
if [ ! -f ${INSTALL_MAPPING} ];then
	echo "Mapping file not found at ${INSTALL_MAPPING}"
	showUsage 1
fi

#force reinstall
if [ "$forceArg" == "-force" ];then
	force=1
else
	force=0
fi


#Resolve full path
TIBCO_ROOT=`cd ${TIBCO_ROOT}; pwd -P`

#Fixed file name
installFile=${HOME}/tibco-installation.properties

#Get existing ROOT --> cannot update it
if [  -f ${installFile} ];then
	EXISTING_TIBCO_ROOT=`cat ${installFile} | grep -wE ^TIBCO_ROOT | awk -F '=' 'NR==1 {print $2}'`
	if [ "${EXISTING_TIBCO_ROOT}" != "" ] && [ -d "${EXISTING_TIBCO_ROOT}" ];then
		echo "Reuse existing TIBCO_ROOT directory : ${EXISTING_TIBCO_ROOT}"
		TIBCO_ROOT=${EXISTING_TIBCO_ROOT}
	fi
fi

#init default
#TIBCO
#Allow multiple HOME (06/02/2017)
TIBCO_ENVNAME=${USER}-HOME
TIBCO_CONFIG_ROOT_DIR=${TIBCO_ROOT}/config
TIBCO_CONFIG_DIR=${TIBCO_CONFIG_ROOT_DIR}/tibco
TIBCO_ENV_INFOS=${HOME}/.TIBCOEnvInfo/_envInfo.xml
TIBCO_CREATE_NEW_ENV=true

	
#Set temp and config dir
TMP_DIR=${TIBCO_ROOT}/tmp/SOFT

#The installer for linux
if [ "`uname`" == "AIX" ];then
	TIBCO_INSTALLER=TIBCOUniversalInstaller-aix.bin
	TIBCO_OS_INSTALL_DIR=aixpower

elif [ "`uname`" == "Linux" ];then
	TIBCO_INSTALLER=TIBCOUniversalInstaller-lnx-x86.bin
	TIBCO_INSTALLER_64=TIBCOUniversalInstaller-lnx-x86-64.bin
	TIBCO_OS_INSTALL_DIR=linux

else
	echo "Message only AIX and Linux supported"
	exit 3

fi

#Verify
if [ ! -d ${BIN_HOME}/extensions ];then
	echo "binaries not found at ${BIN_HOME}/extensions"
	showUsage 1
fi

#set LGPL binaries for BW6
LGPLAssemblyPath=${BIN_HOME}/${TIBCO_OS_INSTALL_DIR}/lgpl

#set 3rd parties binaries for BW6 Plugins
ThirdPartiesPath=${BIN_HOME}/${TIBCO_OS_INSTALL_DIR}/thirdparties

echo "------------------------------------------------------"
echo "Start install binairies at : `date`"
echo "------------------------------------------------------"

#For previous installers
if [ ! -f ${TIBCO_ENV_INFOS} ] && [ -d ${HOME}/InstallShield ];then
	mv ${HOME}/InstallShield ${HOME}/InstallShield_old
fi

if [ -f  $HOME/.TIBCOInstallerInstance$USER ];then
	echo "removing previous installer crashes"
	rm -f $HOME/.TIBCOInstallerInstance$USER 
fi

#Search existing env
readInstallInfos
status=$?
if [ $status -ne 0 ];then
	echo "Error occured"
	cd ${CURRENT_DIR}
	exit $status
fi

#set -x
#if not patch
if [ -d ${BIN_HOME}/${TIBCO_OS_INSTALL_DIR} ];then

	#install binaries
	for f in ${BIN_HOME}/${TIBCO_OS_INSTALL_DIR}/*; do
		installArchive "$f"
		status=$?
		if [ $status -ne 0 ];then
			echo "Error occured"
			cd ${CURRENT_DIR}
			exit $status
		fi
	done

	#install hofixes
	cd ${CURRENT_DIR}
	for f in ${BIN_HOME}/${TIBCO_OS_INSTALL_DIR}/hotfixes/*; do
		installArchive "$f"
		status=$?
		if [ $status -ne 0 ];then
			echo "Error occured"
			cd ${CURRENT_DIR}
			exit $status
		fi
	done

	#install simple hofixes
	cd ${CURRENT_DIR}
	for f in ${BIN_HOME}/${TIBCO_OS_INSTALL_DIR}/hotfixes/SimpleHotfixes/*; do
		installSimpleHotFix "$f"
		status=$?
		if [ $status -ne 0 ];then
			echo "Error occured"
			cd ${CURRENT_DIR}
			exit $status
		fi
	done
fi


#Update EMS/RVD Daemon
if [ "`uname`" == "Linux" ];then
	if [ `uname -a | grep x86_64 | wc -l` -gt 0 ];then
		cd ${CURRENT_DIR}
		updateEMS64BitDaemon
		status=$?
		if [ $status -ne 0 ];then
			echo "Error occured"
			cd ${CURRENT_DIR}
			exit $status
		fi
		
		cd ${CURRENT_DIR}
		updateRVD64BitDaemon
		status=$?
		if [ $status -ne 0 ];then
			echo "Error occured"
			cd ${CURRENT_DIR}
			exit $status
		fi	
	fi
fi


#install jdbc
cd ${CURRENT_DIR}
installJdbcDrivers
status=$?
if [ $status -ne 0 ];then
	echo "Error occured"
	cd ${CURRENT_DIR}
	exit $status
fi

#Install BW EMS drivers ==> For BW6.x
#cd ${CURRENT_DIR}
#installBWEMSDrivers

#createInstallFile
cd ${CURRENT_DIR}
createInstallFile
status=$?
if [ $status -ne 0 ];then
	echo "Error occured"
	cd ${CURRENT_DIR}
	exit $status
fi


#Correct TRA bug
if [ -f ${TIBCO_ROOT}/.installerregistrylock ];then
	rm -f ${TIBCO_ROOT}/.installerregistrylock
	echo "${TIBCO_ROOT}/.installerregistrylock removed"
fi


#update exec mode ==> admin and exploit script commented 
echo ""
echoNoNewLine "modifing exec rights for scripts :"
#chmod -R ug+rx ${SCRIPT_HOME}/administration/unix
#chmod -R ug+rx ${SCRIPT_HOME}/exploitation/unix
#chmod -R ug+rx ${SCRIPT_HOME}/properties
echo "OK"

echo "------------------------------------------------------"
echo "End install binairies at : `date`"
echo "------------------------------------------------------"
cd ${CURRENT_DIR}
exit 0

