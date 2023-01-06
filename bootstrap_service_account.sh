#!/bin/env zsh

source .env

sa_name="editor-sa"

gcloud iam service-accounts create $sa_name \
    --description="The roles/editor service account I am using to invoke all my TF commands." \
    --display-name="$sa_name"

gcloud projects add-iam-policy-binding $project_name \
    --member="serviceAccount:$sa_name@$project_name.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud iam service-accounts keys create $sa_name-private-key.json \
    --iam-account=$sa_name@$project_name.iam.gserviceaccount.com

mv $sa_name-private-key.json ~/.google
