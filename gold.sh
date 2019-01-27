#!/bin/bash

# set virtualenv
source ~/dev/oci/virtualenv/bin/activate

idle_role_tag="idle"
build_tag="2019.01.001"

echo "Starting to provision a gold instance..."
# create an instance based on template. blocking enabled, so that we get the instance details synchronously.
# template used creates only a single vnic for the sample. this is likely inadequate for actual use, however
# the bandwidth for the compute shape is fixed, regardless of the #of vnics.
instance_detail=$(oci compute instance launch --from-json file://instance.json)

compartment_id=$(echo ${instance_detail}|jq -r '.data["compartment-id"]')
instance_id=$(echo ${instance_detail}|jq -r '.data["id"]')

echo "Instance is up. Instance id: ${instance_id}"

oci compute vnic-attachment list --compartment-id=${compartment_id} --instance-id=${instance_id}
# get vnic attachments from the instance
vnic_attachments=$(oci compute vnic-attachment list --compartment-id=${compartment_id} --instance-id=${instance_id})

# get vnic-id for the vnic. Assuming a single vnc here for sample. Assumption is likely wrong given bandwidth requirements.
vnic_id=$(echo ${vnic_attachments}|jq -r '.data[0]["vnic-id"]')

echo "Vnic Id for instance : ${vnic_id}"

# get vnic details
vnic_detail=$(oci network vnic get --vnic-id=${vnic_id})

# get the Public IP
public_ip=$(echo ${vnic_detail}|jq -r '.data["public-ip"]') 
echo "Public IP for instance : ${public_ip}"


echo "Waiting for configuration to complete..."
# SSH in to the instance and block until cloud-init is done.
# cloud init is async, this ensures that everything looks good when we build the image out of this instance.
#@TODO : parametrize SSH keys

false
while [ $? -ne 0 ]; do
    ssh -o StrictHostKeyChecking=no -i munich opc@${public_ip} 'while [ ! -f /tmp/signal ]; do sleep 1; done' || (sleep 1;false)
done

# @TODO - optionally add a step to verify docker image pull.

echo "Gold instance created. Cutting an image from the instance."

# cloud init has finished - docker installed, and images pulled.
# Create the image from the gold instance
image_detail=$(oci compute image create --compartment-id=${compartment_id} --instance-id=${instance_id} --wait-for-state="AVAILABLE")

# get the gold Image Id. At this point we can spin up instances based on this image. However, instance pools make management easier.
gold_image_id=$(echo ${image_detail}|jq -r -C '.data["id"]')
echo "Gold image created. Image Id : ${gold_image_id}"


# create an instance configuration based on the gold instance.
# setup the instance config from a template. @TODO better templating

cat inst_conf.json |jq --arg gold_image_id "$gold_image_id" '.launchDetails["source-details"]["image-id"] = $gold_image_id'\
    |jq --arg idle_role_tag "$idle_role_tag" '.launchDetails["freeform-tags"]["instance_role"] = $idle_role_tag'\
    |jq --arg build_tag "$build_tag" '.launchDetails["freeform-tags"]["build"] = $build_tag'\
    |jq '.launchDetails["display-name"] = "node"'\
    |jq '.launchDetails["create-vnic-details"]["display-name"] = "localnode"'\
    |jq --arg compartment_id "$compartment_id" '.launchDetails["compartment-id"] = $compartment_id' > clone_config.json

## Whats below : uses instance pools to deal with the resources in units larger than a single instance. Completely optional.
# use the template to create an instance config. We'll use this to create a pool and spin up the fleet.

inst_config_detail=$(oci compute-management instance-configuration create --compartment-id=${compartment_id} --instance-details=file://clone_config.json)

# get the isntance config ID
inst_config_id=$(echo ${inst_config_detail}|jq -r '.data["id"]')
echo "Instance Config created. Config Id : ${inst_config_id}"

# using the instance config, we can now create a pool.
# the pool manages instance placement, and distribution as well as provisiding the ability to interact with the whole pool in one operation (start/stop/terminate)

# The pool requires a placement configuration. ex: a pool may make use of only 2/3 ADs. In this example, we use all 3 ADs in PHX.
# Different regions may have a different number of ADs. (PHX has 3, YYZ has 1)

inst_pool_detail=$(oci compute-management instance-pool create --compartment-id=${compartment_id} --instance-configuration-id=${inst_config_id} --placement-configurations=file://phx-placement.json --size=3 --wait-for-state="RUNNING")

inst_pool_id=$(echo ${inst_pool_detail}|jq -r '.data["id"]')

echo "Instance Pool created. Pool Id : ${inst_pool_id}"