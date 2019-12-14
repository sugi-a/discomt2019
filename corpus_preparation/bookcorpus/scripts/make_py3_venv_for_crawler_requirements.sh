#!/bin/bash -e

cd $(dirname $0)/..

echo 'Creating venv'
mkdir bookcorpus_venv
python3 -m venv ./bookcorpus_venv

echo 'Installing required modules into venv'
source ./bookcorpus_venv/bin/activate
pip install -r ./bookcorpus/requirements.txt
pip install numpy
