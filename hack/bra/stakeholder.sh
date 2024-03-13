#!/bin/bash

pid=$$
self=$(basename $0)
tmp=/tmp/${self}-${pid}

declare -A applications
declare -A stakeholders


usage() {
  echo "Usage: ${self} <required> <options>"
  echo "  -h help"
  echo "Required"
  echo "  -u URL."
  echo "  -d directory of binaries."
  echo "Options:"
  echo "  -o output"
}

while getopts "u:d:h" arg; do
  case $arg in
    u)
      host=$OPTARG/hub
      ;;
    d)
      dirPath=$OPTARG
      ;;
    h)
      usage
      exit 1
  esac
done

if [ -z "${dirPath}"  ]
then
  echo "-d required."
  usage
  exit 1
fi
if ! test -d "${dirPath}"
then
  echo "${dirPath} not a directory." 
  exit 1
fi

if [ -z "${host}"  ]
then
  echo "-u required."
  usage
  exit 0
fi


print() {
  if [ -n "${output}"  ]
  then
    echo -e "$@" >> ${output}
  else
    echo -e "$@"
  fi
}


findApps() {
  code=$(curl -kSs -o ${tmp} -w "%{http_code}" ${host}/applications)
  if [ ! $? -eq 0 ]
  then
    exit $?
  fi
  case ${code} in
    200)
      readarray report <<< $(jq -c '.[]|"\(.id) \(.name)"' ${tmp})
      for r in "${report[@]}"
      do
        r=${r//\"/}
        a=($r)
        id=${a[0]}
        name=${a[1]}
        if [ -n "${name}" ]
        then
	  name=$(basename ${name})
          applications["${name}"]=${id}
        fi
      done
      ;;
    *)
      print "find applications - FAILED: ${code}."
      cat ${tmp}
      exit 1
  esac
}

findOwners() {
  code=$(curl -kSs -o ${tmp} -w "%{http_code}" ${host}/stakeholders)
  if [ ! $? -eq 0 ]
  then
    exit $?
  fi
  case ${code} in
    200)
      readarray report <<< $(jq -c '.[]|"\(.id) \(.name)"' ${tmp})
      for r in "${report[@]}"
      do
        r=${r//\"/}
        a=($r)
        id=${a[0]}
        name=${a[1]}
        if [ -n "${name}" ]
        then
          stakeholders["${name}"]=${id}
        fi
      done
      ;;
    *)
      print "find stakeholders - FAILED: ${code}."
      cat ${tmp}
      exit 1
  esac
}


ensureOwnerCreated() {
  path=$1
  name=${path}
  d="
---
name: ${name}
email: "${name}@redhat.com"
"
  code=$(curl -kSs -o ${tmp} -w "%{http_code}" -X POST ${host}/stakeholders -H 'Content-Type:application/x-yaml' -d "${d}")
  if [ ! $? -eq 0 ]
  then
    exit $?
  fi
  case ${code} in
    201)
      ownerId=$(cat ${tmp}|jq .id)
      print "stakeholder for: ${path} created. id=${ownerId}"
      ;;
    409)
      print "stakeholder for: ${path} found."
      ;;
    *)
      print "create skakeholder - FAILED: ${code}."
      cat ${tmp}
      exit 1
  esac
}


ensureOwnersCreated() {
  for p in $(find ${dirPath} -type f)
  do
    p=$(basename ${p})
    name="${p%.*}"
    ensureOwnerCreated ${name}
  done
}

assignOwner() {
  ownerName=$1
  ownerId=$2
  appName=$3
  appId=$4
  d="
---
owner:
  id: ${ownerId}
" 
  code=$(curl -kSs -o ${tmp} -w "%{http_code}" -X PUT ${host}/applications/${appId}/stakeholders -H 'Content-Type:application/x-yaml' -d "${d}")
  if [ ! $? -eq 0 ]
  then
    exit $?
  fi
  case ${code} in
    204)
      print "${appName} (id=${appId}) assigned owner ${ownerName} (id=${ownerId})"
      ;;
    *)
      print "assign owner - FAILED: ${code}."
      cat ${tmp}
      exit 1
  esac

}

assignOwners() {
  for p in $(find ${dirPath} -type f)
  do
    owner="${p#.*}"
    owner=$(basename ${owner})
    ownerId=${stakeholders["${owner}"]}
    while read -r entry
    do
      echo "ENTRY=$entry"
      entry=$(basename ${entry})
      appId=${applications[${entry}]}
      assignOwner ${owner} ${ownerId} "*/${entry}" ${appId}
    done < ${p}
  done
}

findApps
ensureOwnersCreated
findOwners
assignOwners




