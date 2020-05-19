#!/bin/bash

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export $(grep -v '^#' .env | xargs);
aws iam list-attached-role-policies --role-name ${role_name} | grep $policy_name
echo ""
echo "attaching role - $role_name to policy - $policy_name"; 
echo ""
aws iam attach-role-policy --role-name ${role_name} --policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}
