#!/bin/bash

echo -ne "Enter your quay.io username: "
read QUAY_USER
echo -ne "Enter your quay.io password: "
read -s QUAY_PASSWORD
echo -ne "\nEnter your Git Token: "
read -s GIT_AUTH_TOKEN

echo ""
mkdir -p /var/tmp/code-to-prod-demo/
echo "RHACM"

#git clone https://github.com/ch-stark/acminstall
#cd acminstall/rhacmv2
#oc apply -f v2_namespace.yaml -n open-cluster-management
#oc create secret generic pull-secret -n open-cluster-management --from-file=.dockerconfigjson=../../pull-secret --type=kubernetes.io/dockerconfigjson
#oc apply -f v2_operatorgroup.yaml -n open-cluster-management
#oc apply -f v2_subscription.yaml  -n open-cluster-management
#oc apply -f v2_multiclusterhub.yaml -n open-cluster-management

#https://docs.openshift.com/container-platform/4.5/pipelines/installing-pipelines.html

#export MACHINESETS=$(oc get machineset -n openshift-machine-api -o json | jq '.items[]|.metadata.name' -r )
#
#for ms in $MACHINESETS
#do
#   oc scale  MACHINESET $ms --replicas=0 -n openshift-machine-api
#   oc patch MACHINESET $ms -p='{"spec":{"template":{"spec":{"providerSpec":{"value":{"spotMarketOptions":{"maxPrice":0.51}}}}}}}' --type=merge  -n openshift-machine-api
#   oc patch MACHINESET $ms -p='{"spec":{"template":{"spec":{"providerSpec":{"value":{"instanceType":"m5.xlarge"}}}}}}' --type=merge  -n openshift-machine-api
#   oc scale  MACHINESET $ms --replicas=1 -n openshift-machine-api
#done


#sleep 300



cat <<EOF | oc -n openshift-operators create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator-rh
spec:
  channel: ocp-4.5
  installPlanApproval: Automatic
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF



sleep 120
mkdir -p /var/tmp/code-to-prod-demo
git clone git@github.com:mvazquezc/reverse-words.git /var/tmp/code-to-prod-demo/reverse-words
git clone git@github.com:mvazquezc/reverse-words-cicd.git /var/tmp/code-to-prod-demo/reverse-words-cicd
cd /var/tmp/code-to-prod-demo/reverse-words-cicd
git checkout ci
sleep 10
echo "Create Tekton resources for the demo"
oc create namespace reversewords-ci
sed -i "s/<username>/$QUAY_USER/" quay-credentials.yaml
sed -i "s/<password>/$QUAY_PASSWORD/" quay-credentials.yaml
oc -n reversewords-ci delete secret image-updater-secret
oc -n reversewords-ci create secret generic image-updater-secret --from-literal=token=${GIT_AUTH_TOKEN}
oc -n reversewords-ci  apply -f quay-credentials.yaml
oc -n reversewords-ci  apply -f pipeline-sa.yaml
oc -n reversewords-ci  apply -f lint-task.yaml
oc -n reversewords-ci  apply -f test-task.yaml
oc -n reversewords-ci  apply -f build-task.yaml
oc -n reversewords-ci  apply -f image-updater-task.yaml
sed -i "s|<reversewords_git_repo>|https://github.com/mvazquezc/reverse-words|" build-pipeline.yaml
sed -i "s|<reversewords_quay_repo>|quay.io/mavazque/tekton-reversewords|" build-pipeline.yaml
sed -i "s|<golang_package>|github.com/ch-stark/reverse-words|" build-pipeline.yaml
sed -i "s|<imageBuilder_sourcerepo>|mvazquezc/reverse-words-cicd|" build-pipeline.yaml
oc -n reversewords-ci  apply -f build-pipeline.yaml
oc -n reversewords-ci  apply -f webhook-roles.yaml
oc -n reversewords-ci  apply -f github-triggerbinding.yaml
WEBHOOK_SECRET="v3r1s3cur3"
oc -n reversewords-ci create secret generic webhook-secret --from-literal=secret=${WEBHOOK_SECRET}
sed -i "s/<git-triggerbinding>/github-triggerbinding/" webhook.yaml
sed -i "/ref: github-triggerbinding/d" webhook.yaml
sed -i "s/- name: pipeline-binding/- name: github-triggerbinding/" webhook.yaml
oc -n reversewords-ci  apply -f webhook.yaml
oc -n reversewords-ci  apply -f curl-task.yaml
oc -n reversewords-ci apply -f get-stage-release-task.yaml
sed -i "s|<reversewords_cicd_git_repo>|https://github.com/ch-stark/reverse-words-cicd|" promote-to-prod-pipeline.yaml
sed -i "s|<reversewords_quay_repo>|quay.io/mavazque/tekton-reversewords|" promote-to-prod-pipeline.yaml
sed -i "s|<imageBuilder_sourcerepo>|mvazquezc/reverse-words-cicd|" promote-to-prod-pipeline.yaml
sed -i "s|<stage_deployment_file_path>|./deployment.yaml|" promote-to-prod-pipeline.yaml
oc -n reversewords-ci create -f promote-to-prod-pipeline.yaml
oc -n reversewords-ci create route edge reversewords-webhook --service=el-reversewords-webhook --port=8080 --insecure-policy=Redirect
sleep 15

oc create route passthrough --service=multiclusterhub-operator-webhook -n open-cluster-management


CONSOLE_ROUTE=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}')
RHACM_ROUTE=$(oc -n open-cluster-management get route multicloud-console -o jsonpath='{.spec.host}')
echo "OCP Console: $CONSOLE_ROUTE"
echo "RHACM Console: $RHACM_ROUTE"
