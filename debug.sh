#!/bin/bash
if  [[ -z "$1" ]] ; then 
	bundle update
fi
bundle exec jekyll serve --drafts
