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

### Import DevOps Lib files ###
# Usage: _importLibFiles <lib>
function _importLibFiles() {
    
    getArgs "_lib _libPath _libTmpPath _libTmpMain" "${@}"

    # Check if the lib is available from download
    if [ -f ${_libTmpMain} ]; then
        # Create lib dir and copy
        mkdir -p ${_libPath} && cp -r ${_libTmpPath}/* ${_libPath}
        exitOnError "Could not copy the '${_lib}' library files"
        return 0        
    fi
    
    echoError "DEVOPS Library '${_lib}' not found! (was it downloaded already?)"
    return 1
}

### Check if a value exists in an array ###
# usage: _valueInArray <value> <array>
function _valueInArray() {
    getArgs "_value &@_values" "${@}"
    local _val
    local _pos=0
    for _val in "${_values[@]}"; do
        if [[ "${_val}" == "${_value}" ]]; then 
            _return=${_pos}
            return 0;
        fi
        ((_pos+=1))
    done
    return -1
}

### Import DevOps Libs ###
# Usage: import <lib1> <lib2> ... <libN>
function import() {

    # For each lib
    local _result=0
    while [ "${1}" ]; do
        
        # Current lib
        local _lib="${1}"

        # if lib was already imported
        self _valueInArray ${_lib} "${DOLIBS_IMPORTED[@]}"
        if [[ ${?} -eq 0 ]]; then
            echoInfo "DEVOPS Library '${_lib}' already imported!"

        # If not imported yet
        else
            local _libSpace=(${_lib//./ })
            local _libDir=${_lib/./\/}
            local _libPath=${DOLIBS_DIR}/${_libDir}

            # If it is a local custom lib
            if [[ ${_libSpace} == "local" ]]; then
                # Get local config position
                assign _customPos=self _valueInArray local "${DOLIBS_CUSTOM_NAMESPACE[@]}"
                exitOnError "It was not possible to find a local lib configuration"

                local _libDir=${_libDir/${_libSpace}\//}
                local _libPath=${DOLIBS_CUSTOM_REPO[${_customPos}]}/${_libDir}
            
            # If offline mode use current folders, else check remote
            elif [[ "${DOLIBS_MODE}" != "offline" ]]; then

                # Check if it is a custom lib
                assign _customPos=self _valueInArray ${_libSpace} "${DOLIBS_CUSTOM_NAMESPACE[@]}"
                if [[ ${?} -eq 0 ]]; then            
                    local _gitRepo=${DOLIBS_CUSTOM_REPO[${_customPos}]} 
                    local _gitBranch=${DOLIBS_CUSTOM_BRANCH[${_customPos}]}
                    local _gitDir=${DOLIBS_CUSTOM_TMP_DIR[${_customPos}]}
                    local _libRootParentDir=${DOLIBS_DIR}/${_libSpace}
                    local _libDir=${_libDir/${_libSpace}\//}
                    local _libPath=${DOLIBS_DIR}/${_libSpace}/${_libDir}
                # Else is an internal lib
                else
                    local _gitRepo=${DOLIBS_REPO}
                    local _gitBranch=${DOLIBS_BRANCH}
                    local _gitDir=${DOLIBS_TMP_DIR}
                    local _libRootParentDir=${DOLIBS_DIR}                    
                fi
                
                # Cloned Lib location
                local _gitStatus=${_libRootParentDir}/devops-libs.status
                local _gitTmpStatus=${_gitDir}/devops-libs.status
                local _libTmpPath=${_gitDir}/libs/${_libDir}
                local _libTmpMain=${_libTmpPath}/${DOLIBS_MAIN_FILE}

                # LOCAL
                if [[ "${DOLIBS_MODE}" == "local" ]]; then
                    # Import the lib
                    self _importLibFiles ${_lib} ${_libPath} ${_libTmpPath} ${_libTmpMain}
                    exitOnError "It was not possible to import the library files '${_libTmpPath}'"
                
                # ONLINE (allways clone)
                elif [[ "${DOLIBS_MODE}" == "online" ]]; then

                    # Try to clone the lib code
                    devOpsLibsClone ${_gitRepo} ${_gitBranch} ${_gitDir} ${_gitTmpStatus}
                    exitOnError "It was not possible to clone the library code"
                                    
                    # Import the lib
                    self _importLibFiles ${_lib} ${_libPath} ${_libTmpPath} ${_libTmpMain}
                    exitOnError "It was not possible to import the library files '${_libTmpPath}'"

                    # Update git status
                    cp ${_gitTmpStatus} ${_gitStatus}
                    exitOnError "It was not possible to update git status file '${_gitStatus}'"

                # AUTO (clone when changes are detected)
                elif [[ "${DOLIBS_MODE}" == "auto" ]]; then

                    # Get git statuses
                    local _currentHash=$([ ! -f "${_gitTmpStatus}" ] || cd ${_gitDir} && git rev-parse HEAD)
                    local _remoteHash=$([ ! -f "${_gitTmpStatus}" ] || cd ${_gitDir} && git rev-parse origin/${_gitBranch})

                    # Code not cloned / Changed detected
                    if [[ ! -f "${_gitTmpStatus}" || "${_currentHash}" != "${_remoteHash}" ]]; then

                        echoInfo "AUTO MODE - '${_lib}' has changed, cloning code..."

                        # Try to clone the lib code
                        devOpsLibsClone ${_gitRepo} ${_gitBranch} ${_gitDir} ${_gitTmpStatus}
                        exitOnError "It was not possible to clone the library code"

                        # Import the lib
                        self _importLibFiles ${_lib} ${_libPath} ${_libTmpPath} ${_libTmpMain}
                        exitOnError "It was not possible to import the library files '${_libTmpPath}'"                        
                    fi

                    # If not found locally or branch has changed, import
                    if [[ ! -f "${_gitStatus}" || "$(cat ${_gitTmpStatus})" != "$(cat ${_gitStatus})" ]]; then

                        self _importLibFiles ${_lib} ${_libPath} ${_libTmpPath} ${_libTmpMain}
                        exitOnError "It was not possible to import the library files '${_libTmpPath}'"

                        # Update git status
                        cp ${_gitTmpStatus} ${_gitStatus}
                        exitOnError "It was not possible to update git status file '${_gitStatus}'"                        
                    fi
                fi
            fi

            # local CURRENT_LIB_FUNC=${FUNCNAME##*.}
            local _libMain=${_libPath}/${DOLIBS_MAIN_FILE}
            local _libContext='local CURRENT_LIB=${FUNCNAME%.*}; CURRENT_LIB=${CURRENT_LIB#*.};
                               local CURRENT_LIB_DIR='${_libRootParentDir}'/${CURRENT_LIB/./\/}'

            # Check if there was no error importing the lib files
            if [ ${?} -eq 0 ]; then
                # Import lib
                source ${DOLIBS_LIB_FILE} ${_lib} ${_libPath}
                exitOnError "Error importing '${_libMain}'"

                # Get lib function names
                local _libFuncts=($(bash -c '. '"${DOLIBS_LIB_FILE} ${_lib} ${_libPath}"' &> /dev/null; typeset -F' | awk '{print $NF}'))

                # Create the functions
                _createLibFunctions ${_lib} "${_libContext}" ${_libFuncts}
            else 
                ((_result+=1)); 
            fi

            # Set as imported
            export DOLIBS_IMPORTED+=(${_lib})

            # Show import
            echoInfo "Imported Library '${_lib}' (${_funcCount} functions)"
        fi

        # Go to next arg
        shift
    done

    # Case any libs was not found, exit with error
    exitOnError "Some DevOps Libraries were not found!" ${_result}
}

# Function to add a custom lib source
# Usage: _addCustomSource <type> <space> <git_url> <optional_branch>
function _addCustomSource() {

    getArgs "_namespace _url &_branch" "${@}"

    # Set default branch case not specified
    if [ ! "${_branch}" ]; then _branch="master"; fi
    
    # Add the custom repo
    local _pos=${#DOLIBS_CUSTOM_NAMESPACE[@]}
    DOLIBS_CUSTOM_NAMESPACE[${_pos}]="${_namespace}"
    DOLIBS_CUSTOM_REPO[${_pos}]="${_url}"
    DOLIBS_CUSTOM_BRANCH[${_pos}]="${_branch}"
    DOLIBS_CUSTOM_TMP_DIR[${_pos}]="${DOLIBS_DIR}/.libtmp/custom/${_namespace}/${_branch}"
}

# Function to add a custom lib git repository source
# Usage: addCustomGitSource <namespace> <git_url> <optional_branch>
function addCustomGitSource() {

    getArgs "_namespace _url &_branch" "${@}"

    # Check if in local mode
    [[ ${DOLIBS_MODE} != 'local' && ${DOLIBS_MODE} != 'offline' ]] || exitOnError "Custom remote sources are not supported in '${DOLIBS_MODE}' mode!"
    [[ ${_namespace} != "local" ]] || exitOnError "Namespace 'local' is reserved for local sources!"

    self _addCustomSource ${_namespace} ${_url} ${_branch}    
    echoInfo "Added custom GIT lib '${_namespace}'"
}

# Function to add a custom lib git repository source
# Usage: addLocalSource <path>
function addLocalSource() {

    getArgs "_path" "${@}"

    # Get the real path
    _path="$(cd ${_path}/ >/dev/null 2>&1 && pwd)"

    # Check if in local mode
    [[ -d "${_path}" ]] || exitOnError "Library path '${_path}' not found!"

    # Add local source
    self _addCustomSource "local" ${_path}
    echoInfo "Added local source '${_path}'"
}