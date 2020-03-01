#    Copyright 2020 Leonardo Andres Morales

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

#!/bin/bash
export DOLIBS_MAIN_FILE="main.sh"
DOLIBS_REPO="https://github.com/masterleros/bash-devops-libs.git"
DOLIBS_TMPDIR="${DOLIBS_DIR}/.libtmp"

### Show a info text
# usage: echoInfo <text>
function echoInfo() {
    local IFS=$'\n'
    local _text="${1/'\n'/$'\n'}"
    local _lines=(${_text})
    local _textToPrint="INFO:  "
    for _line in "${_lines[@]}"; do
        echo "${_textToPrint} ${_line}"
        _textToPrint="       "
    done
}

### Show a test in the stderr
# usage: echoError <text>
function echoError() {
    local IFS=$'\n'
    local _text="${1/'\n'/$'\n'}"
    local _lines=(${_text})
    local _textToPrint="ERROR: "
    for _line in "${_lines[@]}"; do
        echo "${_textToPrint} ${_line}" >&2
        _textToPrint="       "
    done
}

### Exit program with text when last exit code is non-zero ###
# usage: exitOnError <output_message> [optional: forced code (defaul:exit code)]
function exitOnError() {
    local _errorCode=${2:-$?}
    local _errorText=${1}
    if [ "${_errorCode}" -ne 0 ]; then
        if [ ! -z "${_errorText}" ]; then
            echoError "${_errorText}"
        else
            echoError "At '${BASH_SOURCE[-1]}' (Line ${BASH_LINENO[-2]})"
        fi
        echo "Exiting (${_errorCode})..."
        exit "${_errorCode}"
    fi
}

### Function to clone the lib code ###
# usage: libGitClone <GIT_REPO> <GIT_BRANCH> <GIT_DIR> <LIB_ROOT_DIR>
function libGitClone() {

    local GIT_REPO=${1}
    local GIT_BRANCH=${2}
    local GIT_DIR=${3}
    local LIB_ROOT_DIR=${4}
    local SOURCE_STATE="${LIB_ROOT_DIR}/.source.state"

    # Check if git is present
    which git &> /dev/null || exitOnError "Git command not found"            

    # Get the code        
    if [ ! -d "${GIT_DIR}" ]; then            
        echoInfo "Cloning Libs code from '${GIT_REPO}'..."
        git clone -q -b "${GIT_BRANCH}" --single-branch "${GIT_REPO}" "${GIT_DIR}"
    else
        echoInfo "Updating Libs code from '${GIT_REPO}'..."
        git -C "${GIT_DIR}" pull -q
    fi
    exitOnError "It was not possible to clone the GIT code"

    # Update retrieved lib status
    mkdir -p "${LIB_ROOT_DIR}"
    cat << EOF > "${SOURCE_STATE}"
GIT_DIR:${GIT_DIR}
GIT_BRANCH:${GIT_BRANCH}
GIT_HASH:$(cd "${GIT_DIR}"; git rev-parse HEAD)
GIT_USER:$(git config user.name)
GIT_EMAIL:$(git config user.email)
UPDATED:$(date)
HOSTNAME:$(hostname)
EOF
   
}

### Function to indicate if the lib code is outdated ###
# usage: libGitOutDated <LIB_ROOT_DIR>
function libGitOutDated() {

    local LIB_ROOT_DIR=${1}
    local GIT_DIR=${2}
    local SOURCE_STATE="${LIB_ROOT_DIR}/.source.state"

    # If state dos not exist
    [ -f "${SOURCE_STATE}" ] || return 0

    # If source dos not exist
    [ -d "${GIT_DIR}" ] || return 0

    # Get local status
    local GIT_BRANCH=$(< "${SOURCE_STATE}" grep GIT_BRANCH | cut -d':' -f2-)    
    local GIT_HASH=$(< "${SOURCE_STATE}" grep GIT_HASH | cut -d':' -f2-)

    # Get git remote hash
    local GIT_ORIGIN_HASH=$(cd "${GIT_DIR}" && git fetch -q && git rev-parse origin/"${GIT_BRANCH}")

    # Return result
    [ "${GIT_ORIGIN_HASH}" != "${GIT_HASH}" ]
}

### Function to indicate if the source if different than the lib ###
# usage: libSourceUpdated <SOURCE_DIR> <LIB_DIR>
function libSourceUpdated() {
    local SOURCE_DIR=${1}
    local LIB_DIR=${2}

    # Validate source and lib folder differences
    [ "$(cd "${SOURCE_DIR}"; find -maxdepth 1 -type f -exec diff {} "${LIB_DIR}"/{} \; 2>&1)" ]
}

### Import Lib files ###
# Usage: libImportFiles <SOURCE_DIR> <LIB_DIR>
function libImportFiles() {
    
    local SOURCE_DIR=${1}
    local LIB_DIR=${2}
    local LIB=${3}
    local LIB_SHASUM_PATH="${LIB_DIR}/.lib.shasum"

    echoInfo "Installing '${LIB}' code..."

    # Check if the lib entrypoint exists
    [ -f "${SOURCE_DIR}/${DOLIBS_MAIN_FILE}" ] || exitOnError "Library source '${SOURCE_DIR}' not found! (does it need add source?)"

    # Create lib dir and copy
    mkdir -p "${LIB_DIR}" && cp "${SOURCE_DIR}"/*.* "${LIB_DIR}"
    exitOnError "Could not import the '${SOURCE_DIR}' library files"

    # Add the checksum file
    shasum=$(find "${LIB_DIR}" -maxdepth 1 -type f ! -path "${LIB_SHASUM_PATH}" -exec sha1sum {} \; | sha1sum | cut -d' ' -f1)
    echo "SHASUM:${shasum}" > "${LIB_SHASUM_PATH}"
}

### Check if the libs files are valid ###
# Usage: libNotIntegral <LIB_DIR>
function libNotIntegral() {
    
    local LIB_DIR=${1}
    local LIB_SHASUM_PATH="${LIB_DIR}/.lib.shasum"

    # If sha does not exist exist
    [ -f "${LIB_SHASUM_PATH}" ] || return 0
  
    # Get current sha
    local LIB_SHASUM=$(< "${LIB_SHASUM_PATH}" grep SHASUM | cut -d':' -f2-)

    # Calculate sha     
    local CALCULATED_SHASUM=$(find "${LIB_DIR}" -maxdepth 1 -type f ! -path "${LIB_SHASUM_PATH}" -exec sha1sum {} \; | sha1sum | cut -d' ' -f1)

    # Return result
    [ "${LIB_SHASUM}" != "${CALCULATED_SHASUM}" ]    
}

# Show operation mode
if [ ${DOLIBS_MODE} == 'offline' ]; then 
    echoInfo "---> DevOps Libs (${DOLIBS_MODE}) <---"
elif [ ${DOLIBS_LOCAL_SOURCE_DIR} ]; then 
    echoInfo "---> DevOps Libs Local Source: '${DOLIBS_LOCAL_SOURCE_DIR}' (${DOLIBS_MODE}) <---"        
else
    echoInfo "---> DevOps Libs branch: '${DOLIBS_BRANCH}' (${DOLIBS_MODE}) <---"        
fi

# If Core library was not yet loaded
if [ ! "${DOLIBS_CORE_FUNCT}" ]; then

    # core folder
    DOLIBS_CORE_DIR=${DOLIBS_DIR}/core
    DOLIBS_SHDOC_DIR=${DOLIBS_CORE_DIR}/shdoc

    # If not working offline
    if [[ ${DOLIBS_MODE} != 'offline' ]]; then

        # Local mode
        if [ "${DOLIBS_LOCAL_SOURCE_DIR}" ]; then 
            DOLIBS_SOURCE_DIR="${DOLIBS_LOCAL_SOURCE_DIR}"
        # GIT mode
        else 
            DOLIBS_SOURCE_DIR="${DOLIBS_TMPDIR}/core/${DOLIBS_BRANCH}"; 
        fi

        # dolibs core functions dirs
        DOLIBS_SOURCE_CORE_DIR=${DOLIBS_SOURCE_DIR}/core        

        # AUTO mode
        if [ "${DOLIBS_MODE}" == 'auto' ]; then
            # If the lib is not integral, needs to update
            if libNotIntegral "${DOLIBS_CORE_DIR}"; then
                echoInfo "It was not possible to check 'core' lib integrity, trying to get its code..."
                _needInstall=true
            fi
        # ONLINE mode
        elif [ "${DOLIBS_MODE}" == 'online' ]; then
            # If the lib is outdated, clone it
            if libGitOutDated "${DOLIBS_CORE_DIR}" "${DOLIBS_SOURCE_DIR}" || libSourceUpdated "${DOLIBS_SOURCE_CORE_DIR}" "${DOLIBS_CORE_DIR}"; then
                _needInstall=true
            fi
        fi

        # If needs clone
        if [ "${_needInstall}" == "true" ]; then

            # If not in local source clone the lib repo
            if [ ! "${DOLIBS_LOCAL_SOURCE_DIR}" ]; then 
                libGitClone "${DOLIBS_REPO}" "${DOLIBS_BRANCH}" "${DOLIBS_SOURCE_DIR}" "${DOLIBS_CORE_DIR}"
            fi

            # Create doc folder and copy shdoc (documentation)
            mkdir -p "${DOLIBS_SHDOC_DIR}"
            cp "${DOLIBS_SOURCE_CORE_DIR}"/shdoc/* "${DOLIBS_SHDOC_DIR}"

            # Copy the gitignore
            cp "${DOLIBS_SOURCE_DIR}"/.gitignore "${DOLIBS_DIR}"

            # Copy license
            cp "${DOLIBS_SOURCE_DIR}"/LICENSE "${DOLIBS_DIR}"/LICENSE
            cp "${DOLIBS_SOURCE_DIR}"/NOTICE "${DOLIBS_DIR}"/NOTICE

            # Copy the Libs help
            cp "${DOLIBS_SOURCE_DIR}"/README.md "${DOLIBS_DIR}"/README.md
            cp "${DOLIBS_SOURCE_DIR}"/libs/README.md "${DOLIBS_DIR}"/DEVELOPMENT.md

            # import core lib files
            libImportFiles "${DOLIBS_SOURCE_CORE_DIR}" "${DOLIBS_CORE_DIR}" core
        fi
    fi

    ### Include Libs ###
    if [ -f "${DOLIBS_CORE_DIR}"/core.sh ]; then        
        . "${DOLIBS_CORE_DIR}"/core.sh
        exitOnError "Could not import DevOps Libs"
    else
        exitOnError "Could not find DevOps Libs (offline mode?)" 1
    fi
fi

# Check required binaries
# git
# diff
# shasum
