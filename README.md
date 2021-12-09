# infrastructure
Author: Yongji Shen
Date: 2021/10/11


<ol>
    <li>
        <b>aws configure --profile=prod</b><br/>
        update your information for prod
    </li>
    <li>
        <b>export AWS_PROFILE=prod</b><br/>
        switch to prod environment
    </li>
    <li><b>terraform init</b></li>
    <li><b>terraform fmt</b></li>
    <li>
        <b>terraform apply -var-file="terraform.tfvars"</b><br/>
        will ask some information from user<br/>
        <div>
            vpc_name = "test"<br/>
            vpc_cidr_block = "10.0.0.0/16"<br/>
            subnet_cidr_block = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]<br/>
            subnet_availability_zone = ["us-east-1a","us-east-1b","us-east-1c"]<br/>
            enable_dns_hostnames             = true<br/>
            enable_dns_support               = true<br/>
            enable_classiclink_dns_support   = true<br/>
            assign_generated_ipv6_cidr_block = false<br/>
            map_public_ip_on_launch          = true<br/>
            default_destination_cidr_block   = "0.0.0.0/0"<br/>
            You may write those variables into terraform.tfvars
        </div>
    </li>
    <li>
        <b>terraform destroy -var-file="terraform.tfvars"</b><br/>
        will ask some information from user<br/>
        <div>
            vpc_name = "test"<br/>
            vpc_cidr_block = "10.0.0.0/16"<br/>
            subnet_cidr_block = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]<br/>
            subnet_availability_zone = ["us-east-1a","us-east-1b","us-east-1c"]<br/>
            enable_dns_hostnames             = true<br/>
            enable_dns_support               = true<br/>
            enable_classiclink_dns_support   = true<br/>
            assign_generated_ipv6_cidr_block = false<br/>
            map_public_ip_on_launch          = true<br/>
            default_destination_cidr_block   = "0.0.0.0/0"<br/>
            You may write those variables into terraform.tfvars
        </div>
    </li>
    <li>
    <div>
        In order to import crt, pem to aws, please run importAWSCert.sh by ./importAWSCert.sh
    </div>
    </li>

</ol>