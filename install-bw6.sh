#!/bin/bash
#set -x
#-----------------------------------------
# Installation script BW 5 & 6(.x) for Linux/AIX
# Author : GERARD KOUASSI 
#-----------------------------------------


#-----------------------------------------------------
#		failInstall
#-----------------------------------------------------
failInstall(){
	echo "Installation failed, $1"
}

#-----------------------------------------------------
#		sub routines (associative array)
#----------------------------------------------------- 

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
#		function getFileNameNoVersion
#----------------------------------------------------- 
function getFileNameNoVersion
{	
	local inputstr=$1
	local currentNameStr=	
	typeset -i charIndex=1
	typeset -i nextCharIndex=0

	local nameLength=${#inputstr}
	while [ ${charIndex} -le ${nameLength} ];do
	   curChar=$(expr substr "$inputstr" ${charIndex} 1)			   
	   if [ "${curChar}" != "-" ];then
			currentNameStr=${currentNameStr}${curChar}
	    else
			nextCharIndex=charIndex+1
			nextChar=$(expr substr "$inputstr" ${nextCharIndex} 1)
			if [ $(isNumeric ${nextChar}) -eq 1 ];then
				break
			else
				currentNameStr=${currentNameStr}${curChar}
			fi
	   fi
	   charIndex=charIndex+1
	done
	echo $currentNameStr
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
		if [ -d $basedir/$f ];then
			if [ "$2" != "" ];then
				#test file
				if [ ! -f $basedir/$f/$2 ] && [ ! -d $basedir/$f/$2 ];then
					continue;
				fi
			fi
			
			charIndex=1
			currentVersionStr=
			nameLength=${#f}
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
			local fiName=$(getFileNameNoVersion ${fiNameVersion})
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

EXT_HOME=`dirname $prg`
EXT_HOME=`cd ${EXT_HOME}; pwd -P`
EXT_NEW_VERSION=`basename $EXT_HOME`

#Cls if no arg
if [ $# -eq 0 ];then
	clear
else
	echo
fi

echo "------------------------------------------------------"
echo "Start install JDBC drivers at : `date`"
echo "------------------------------------------------------"
echo
echo "JDBC drivers binary is located at ${EXT_HOME}"
echo "JDBC drivers version is ${EXT_NEW_VERSION}"

#Fixed file name
installFile=${HOME}/tibco-installation.properties

if [ $# -gt 0 ];then
	TIBCO_ROOT=`dirname $1`/`basename $1`
else
	if [ ! -f ${installFile} ];then
		failInstall "${installFile} not found, you must call $prg <TIBCO_ROOT>, exemple : $prg /opt/tibco"
		exit 1
	fi
	#Get TIBCO ROOT
	TIBCO_ROOT=`cat ${installFile} | grep -wE ^TIBCO_ROOT | awk -F '=' 'NR==1 {print $2}'`
fi
	

echo "TIBCO_ROOT is ${TIBCO_ROOT}"
if [ "${TIBCO_ROOT}" == "" ];then
	failInstall "TIBCO_ROOT not found"
	exit 1
fi
if [ ! -d ${TIBCO_ROOT} ];then
	failInstall "${TIBCO_ROOT} not found"
	exit 1
fi

if [ ! -d ${TIBCO_ROOT}/bw ];then
	failInstall "${TIBCO_ROOT} is not a valid TIBCO installation directory"
	exit 1
fi
#--------------------------------------------------------------------------------

BW_VERSION=$(locateMaxVersion ${TIBCO_ROOT}/bw system)
if [ "${BW_VERSION}"  == "" ];then 
	echo "BW_VERSION not found"
	return 1
fi
	
#bw drs
TIBCO_BW_SYSTEM_DIR=${TIBCO_ROOT}/bw/${BW_VERSION}/system
TIBCO_BW_SYSTEM_LIB_DIR=${TIBCO_BW_SYSTEM_DIR}/lib
TIBCO_BW_SYSTEM_JDBC_LIB_DIR=${TIBCO_BW_SYSTEM_LIB_DIR}

if [ ! -d ${TIBCO_BW_SYSTEM_JDBC_LIB_DIR} ];then
	echo "${TIBCO_BW_SYSTEM_JDBC_LIB_DIR} not found"
	return 1
fi


echo
echo "Installing drivers on ${TIBCO_BW_SYSTEM_JDBC_LIB_DIR}"
copyVersion ${EXT_HOME} ${TIBCO_BW_SYSTEM_JDBC_LIB_DIR}
if [ $? -ne 0 ];then
	echo "Problem during jdbc drivers installation"
	return 2
fi

echo
echo "${EXT_NEW_VERSION} installed at ${TIBCO_BW_SYSTEM_JDBC_LIB_DIR}"
echo
echo "------------------------------------------------------"
echo "End install ${EXT_NEW_VERSION} at : `date`"
echo "------------------------------------------------------"
exit 0
