#!/bin/bash 

if [ "$1" == "apply" ]
then
    terraform apply -var-file="terraform.tfvars"  
elif [ "$1" == "destroy" ]
then
  aws s3 rm s3://$2 --recursive
  terraform destroy -var-file="terraform.tfvars"
elif [ "$1" == "amiimage" ]
then
    export AWS_PROFILE=dev
    sleep 2
    packer build \
        -var-file "var.pkr.json" \
        ami.json
else
  echo "wrong command"
fi