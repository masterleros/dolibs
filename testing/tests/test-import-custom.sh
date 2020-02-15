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
source $(dirname ${BASH_SOURCE[0]})/../../dolibs.sh -f /tmp

# Set the custom remote lib source
do.addGitSource gitlib "masterleros/bash-devops-libs" master libs
exitOnError
do.import gitlib.utils

# Set the custom lib source
do.addLocalSource locallib $(dirname ${BASH_SOURCE[0]})/../../libs
exitOnError
do.import locallib.utils

### YOUR CODE ###
gitlib.utils.showTitle "External lib import test!"
locallib.utils.showTitle "Local lib import test!"
### YOUR CODE ###