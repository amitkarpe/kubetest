#!/bin/bash

echo "Set/Export all ENV variable from .env file"
export $(grep -v '^#' .env | xargs);
export OIDC_PROVIDER=$(aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///"); echo OIDC_PROVIDER - $OIDC_PROVIDER; echo "";
#echo "associate-iam-oidc-provider with cluster"; aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer"; eksctl utils associate-iam-oidc-provider --cluster $cluster --approve; echo "";

echo ""
echo "List bucket $s3_bucket_name"; aws s3 ls s3://${s3_bucket_name}; 
if [[ $? != 0 ]];
then 
	echo "Creating s3 bucket - $s3_bucket_name";
	aws s3api create-bucket --bucket ${s3_bucket_name}  --region $AWS_DEFAULT_REGION \
	--create-bucket-configuration LocationConstraint=${AWS_DEFAULT_REGION} 
#	--acl private;
	echo "test 1" > test; aws s3 cp test s3://${s3_bucket_name}/;
fi
echo ""

read -r -d '' TRUST_RELATIONSHIP <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${ns}:*"
        }
      }
    }
  ]
}
EOF

echo "Get role name"
aws iam get-role --role-name $role_name;
if [[ $? != 0 ]];
then
	echo "${TRUST_RELATIONSHIP}" > trust.json; cat trust.json| jq
	echo "create role - $role_name"; aws iam create-role --role-name ${role_name} --assume-role-policy-document file://trust.json --description "eks to s3 access role";
fi
echo ""

read -r -d '' POLICY <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
EOF

echo "Get policy name"
aws iam get-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}
if [[ $? != 0 ]];
then 
	echo "${POLICY}" > policy.json; cat policy.json | jq
	echo "create policy - $policy_name"; aws iam create-policy --policy-name ${policy_name} --policy-document file://policy.json --description "Allows full access of S3 bucket from EKS Pod"
fi
echo ""

echo "Get list-attached-role-policies"
aws iam list-attached-role-policies --role-name ${role_name} | grep $policy_name
if [[ $? != 0 ]];
then 
	echo "attach role - $role_name to policy - $policy_name"; aws iam attach-role-policy --role-name ${role_name} --policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}
fi
echo ""


kubectl get deployment s3;
kubectl apply -f ../kubetest/s3.yaml
if [[ $? != 0 ]];
then 
	echo "Deploy s3 deployment into cluster"; kubectl apply -f https://raw.githubusercontent.com/amitkarpe/kubetest/master/s3.yaml; 
#else	
#	kubectl delete pod -l run=s3
fi
echo ""

echo "Annotate serviceaccount"; kubectl get sa -n ${ns} ${service_account}  -o yaml | grep annotations -A 1
echo "kubectl annotate serviceaccount -n ${ns} ${service_account} eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${policy_name} --overwrite"
kubectl annotate serviceaccount -n ${ns} ${service_account} eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${role_name} --overwrite; echo ""

export cmd="aws s3 ls --recursive s3://${s3_bucket_name}/"; export POD=$(kubectl get pods -l "run=${app}" -o jsonpath="{.items[0].metadata.name}"); kubectl exec -it $POD -- $cmd


