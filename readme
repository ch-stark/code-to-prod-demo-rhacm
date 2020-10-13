For running the Demo you need a Hub-Cluster with appropriate sizing.
You can use this scrpt to use Spot-Instances

export MACHINESETS=$(oc get machineset -n openshift-machine-api -o json | jq '.items[]|.metadata.name' -r )

for ms in $MACHINESETS
do
   oc scale  MACHINESET $ms --replicas=0 -n openshift-machine-api
   oc patch MACHINESET $ms -p='{"spec":{"template":{"spec":{"providerSpec":{"value":{"spotMarketOptions":{"maxPrice":0.51}}}}}}}' --type=merge  -n openshift-machine-api
   oc patch MACHINESET $ms -p='{"spec":{"template":{"spec":{"providerSpec":{"value":{"instanceType":"m5.xlarge"}}}}}}' --type=merge  -n openshift-machine-api
   oc scale  MACHINESET $ms --replicas=1 -n openshift-machine-api
done

Please consult the Documentation for more info:

https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.0/html/manage_applications/managing-applications
