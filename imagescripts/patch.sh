#!/bin/bash

SEARCH_IN=./

if [ -d "$2" ]; then
    # Control will enter here if $DIRECTORY exists.
    SEARCH_IN=$2
fi

pushd "${CONFLUENCE_SCRIPTS}"
echo "Patching Atlassian licenses in '$SEARCH_IN'..."

find $SEARCH_IN -type f -name "$1" -print0 | while IFS= read -r -d $'\0' file; do
    jar tf $file | ( \
        grep Version2LicenseDecoder.class \
        && echo "Patching license decoder in '$file'" \
        && jar uf $file com/atlassian/extras/decoder/v2/Version2LicenseDecoder.class \
        );
done

popd