#!/bin/bash

# set virtualenv
source ~/dev/oci/virtualenv/bin/activate

fleet_size=0
compartment_id=""

while getopts ":n:c:p:h" opt; do
  case ${opt} in
    h )
      echo "Usage: create_pool -n [num] -c [path_to_launch_config] -p [path_to_placement_config]"
      echo "        -n [num]     Number of isntances in instance pool"
      echo "        -c [path_to_launch_config] Path to the JSON launch config file "
      exit 0
      ;;
    n )
        fleet_size=$OPTARG
        ;;
    c )
        launch_config_file=$OPTARG
        compartment_id=$(jq -r '.launchDetails["compartment-id"]' ${launch_config_file})
        ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# ---------

echo "Provisioning isntance pool with ${fleet_size} isntances in compartment ${compartment_id}."
exit 1;

# use the template to create an instance config. We'll use this to create a pool and spin up the fleet.

inst_config_detail=$(oci compute-management instance-configuration create --compartment-id=${compartment_id} --instance-details=file://clone_config.json)

# get the isntance config ID
inst_config_id=$(echo ${inst_config_detail}|jq -r '.data["id"]')
echo "Instance Config created. Config Id : ${inst_config_id}"
echo "Creating an Instance Pool with ${fleet_size} nodes. Placement based on config."

#---------
# Using the instance config, we can now create a pool.
# InstancePools give us the ability to interact with the whole pool in one operation (start/stop/terminate)
# The pool requires a placement configuration. ex: a pool may make use of only 2/3 ADs. In this example, we use all 3 ADs in PHX.
# Different regions may have a different number of ADs. (PHX has 3, YYZ has 1)

inst_pool_detail=$(oci compute-management instance-pool create \
    --compartment-id=${compartment_id} --instance-configuration-id=${inst_config_id} \
    --placement-configurations=file://phx-placement.json --size=${fleet_size} --wait-for-state="RUNNING")

inst_pool_id=$(echo ${inst_pool_detail}|jq -r '.data["id"]')

echo "Instance Pool created. Pool Id : ${inst_pool_id}"