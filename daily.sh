#!/usr/bin/bash
read -p "Commit-Messager: (Enter: daily commit):" message

if [[  "$message" == "" ]]; then
	echo "Add,commit,push wird ausgeführt..."
	git add .
	git commit -m "Daily commit"
	git push
else
	echo "Commit-Massage eingegeben"
	git add .
	git commit -m "$message"
	git push
fi
