#!/usr/bin/env bash

if aws s3 ls ${company}-${realm}-tfstate/backend/; then
  echo "S3 backend bucket already exists"
  terraform init -lock=false
  terraform apply -auto-approve
else
  cp config.tf.old config.tf
  terraform init -force-copy
  terraform apply -target=aws_kms_key.tfstate -lock=false -auto-approve
  terraform apply -target=aws_s3_bucket.tfstate -lock=false -auto-approve
  terraform apply -target=aws_dynamodb_table.backend-tfstate -lock=false -auto-approve
  cp config.tf.new config.tf
  terraform init -force-copy -lock=false
  terraform plan -lock=false
  terraform apply -auto-approve
fi
