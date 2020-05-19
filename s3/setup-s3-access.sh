#!/bin/bash

echo "Set/Export all ENV variable from .env file"
export $(grep -v '^#' .env | xargs);
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export OIDC_PROVIDER=$(aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///"); echo OIDC_PROVIDER - $OIDC_PROVIDER; echo "";

if [[ ! -f .setup ]];
then
	kubectl create ns $ns; kubens $ns;
	echo "associate-iam-oidc-provider with cluster"; aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer"; eksctl utils associate-iam-oidc-provider --cluster $cluster --approve; echo "";

	echo ""; echo ${s3_bucket_name}
	echo "List bucket $s3_bucket_name"; aws s3 ls s3://${s3_bucket_name}; 
	if [[ $? != 0 ]];
	then 
		echo "Creating s3 bucket - $s3_bucket_name";
		echo $AWS_DEFAULT_REGION
		aws s3api create-bucket --bucket ${s3_bucket_name} --region ${AWS_DEFAULT_REGION} --create-bucket-configuration LocationConstraint=${AWS_DEFAULT_REGION}
		echo "test $(date)" > test; aws s3 cp test s3://${s3_bucket_name} --region ${AWS_DEFAULT_REGION};
	fi
	echo ""
	echo date - $(date) > .setup; cat .setup;
fi

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
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${ns}:${service_account}"
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
	echo "creating role - $role_name"; aws iam create-role --role-name ${role_name} --assume-role-policy-document file://trust.json --description "eks to s3 access role";
fi
echo ""

sleep 5;
echo "Get list-attached-role-policies"
aws iam list-attached-role-policies --role-name ${role_name} | grep $policy_name
echo "attaching role - $role_name to policy - $policy_name"; 
aws iam attach-role-policy --role-name ${role_name} --policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}
echo ""
aws iam list-attached-role-policies --role-name ${role_name} | grep $policy_name
aws iam list-attached-role-policies --role-name ${role_name} | jq
echo ""


kubectl annotate serviceaccount -n ${ns} ${service_account} eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${role_name} --overwrite; echo ""

kubectl get deployment s3;
#kubectl apply -f ../kubetest/s3.yaml
#kubectl apply -f ../s3.yaml
echo "Deploy s3 deployment into cluster"; 
kubectl replace -f https://raw.githubusercontent.com/amitkarpe/kubetest/master/s3.yaml; 
if [[ $? != 0 ]];
then 
	echo THEN
	echo "Deploy s3 deployment into cluster"; kubectl apply -f https://raw.githubusercontent.com/amitkarpe/kubetest/master/s3.yaml; 
else	
	echo ELSE
#	kubectl delete pod -l run=s3
#	kubectl rollout restart deployment s3
fi
echo ""

echo "Annotate serviceaccount"; kubectl get sa -n ${ns} ${service_account}  -o yaml | grep annotations -A 1
echo "kubectl annotate serviceaccount -n ${ns} ${service_account} eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${policy_name} --overwrite"
kubectl annotate serviceaccount -n ${ns} ${service_account} eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${role_name} --overwrite; echo ""
kubectl delete pod -l run=s3
sleep 5;
kubectl get pod -l run=s3 -o yaml | grep AWS -A2

export url="s3://${s3_bucket_name}"
export cmd="aws s3 ls ${url}"
export POD=$(kubectl get pods -l "run=${app}" -o jsonpath="{.items[0].metadata.name}"); kubectl exec -it $POD -- ${cmd}

