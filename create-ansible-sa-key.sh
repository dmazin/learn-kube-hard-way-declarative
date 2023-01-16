#!/bin/env zsh

source .env

sa_name="ansible"

gcloud iam service-accounts keys create $sa_name-private-key.json \
    --iam-account=$sa_name@$project_name.iam.gserviceaccount.com

mv $sa_name-private-key.json ~/.google/$project_name
