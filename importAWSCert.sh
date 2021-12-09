#!/bin/bash 
export AWS_PROFILE=prod
aws acm import-certificate --certificate fileb://prod_yongjishen_me.crt \
--certificate-chain fileb://prod_yongjishen_me.ca-bundle \
--private-key fileb://secret.pem \
--region us-east-1