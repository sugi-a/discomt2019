#!/bin/sh -e

# Bawden et al, "Evaluating discourse phenomena in neural machine translation"
# https://github.com/rbawden/discourse-mt-test-sets

cd $(dirname $0)

# download
git clone "https://github.com/rbawden/discourse-mt-test-sets.git"

# extract
python ./extract.py
