#!/usr/bin/bash
# read -p "Soll das Skript wirklich ausgeführt werden? (Y/N):" antwort

#if [[  "$antwort" == "Y" || "$antwort" == "y" ]]; then
	echo "Daily add,commit,push wird ausgeführt..."
	git add .
	git commit -m "Daily commit"
	git push
#else
#	echo "Skript wird nicht ausgeführt"
#	exit 1
#fi
