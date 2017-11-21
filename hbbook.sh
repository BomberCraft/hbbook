#!/bin/bash

function fulltrim() {
    echo "$(sed -re 's/\s//g' <<< "$*")";
}

function getFileName() {
    echo "$(sed -re 's/(.+\/)?(.+)[.](.+)([?].+)?$/\2/' <<< "$*")";
}

function getFileExt() {
    echo "$(sed -re 's/(.+\/)?(.+)[.](.+)([?].+)?$/\3/' <<< "$*")";
}

function getPriority() {
    echo "${priorities[$1]:-0}";
}

if [ -z "$1" ]; then
    echo "Usage: $(basename "$0") <humblebundle_book-bundle.html>";
    exit 1;
fi;

if [ "$(getFileExt "${1^^}")" != "HTML" ]; then
    echo "Parameter MUST be a html file!";
    exit 1;
fi;

sourcefile="$1";
outputFolder="$(getFileName "${sourcefile}")";

echo "Gathering all links from html file...";
uris=($(xidel --silent "${sourcefile}" --xpath3 "//a[contains(@href, 'dl.humble.com')]/@href"));
echo "done!";

declare -A priorities;
priorities=([MOBI]=90 [EPUB]=60 [PDF]=30)

declare -A downloadLinks;
downloadLinks=();

i=0;
sp="/-\|";

echo "Reducing links based on priorities...";
for uri in "${uris[@]}"; do
    url="$(fulltrim "${uri}")";
    filename="$(getFileName ${uri})";
    fileext="$(getFileExt ${uri})";
    fileext="${fileext^^}";
    priority="$(getPriority ${fileext})";

    printf "\r  ${sp:i++%${#sp}:1} $i/${#uris[@]}";

    if [ ${downloadLinks[$filename]+_} ]; then
        previousUrl="${downloadLinks[$filename]}";
        previousExt="$(getFileExt ${previousUrl})";
        previousExt="${previousExt^^}";
        previousPriority="$(getPriority ${previousExt})";
        
        if [ "${priority}" -gt "${previousPriority}" ]; then 
            downloadLinks[$filename]="$url";
        fi;
    else
        downloadLinks[$filename]="$url";
    fi;
done;
echo " done!";

i=0;

echo -e "Preparing links for download..."
[[ ! -e "${outputFolder}" ]] && mkdir -p "${outputFolder}";
cd "${outputFolder}";
echo -n "" > urls.txt;
for link in "${!downloadLinks[@]}"; do
    printf "\r  ${sp:i++%${#sp}:1} $i/${#downloadLinks[@]}";
    echo "${downloadLinks[${link}]}" >> urls.txt;
    sleep ".05";
done;
echo " done!";

echo "Launching download...";
wget --no-verbose --no-check-certificate --continue --input-file=urls.txt --content-disposition;
echo "done!";
