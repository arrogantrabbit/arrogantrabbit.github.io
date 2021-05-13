#!/bin/bash
if  [[ -z "$1" ]] ; then 
	bundle update
fi
JEKYLL_ENV=production bundle exec jekyll serve --drafts
