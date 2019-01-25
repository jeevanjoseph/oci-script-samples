#!/bin/bash

# set virtualenv
source ~/dev/oci/virtualenv/bin/activate

# create an instance based on template. blocking enabled, so that we get the instance details synchronously.
# template used creates only a single vnic for the sample. this is likely inadequate for actual use, however
# the bandwidth for the compute shape is fixed, regardless of the #of vnics.
instance_detail=$(oci compute instance launch --from-json file://instance.json)

compartment_id=$(echo $instance_detail|jq '.data["compartment-id"]'|sed "s/\"//g")
instance_id=$(echo $instance_detail|jq '.data["id"]'|sed "s/\"//g")

# get vnic attachments from the instance
vnic_attachments=$(oci compute vnic-attachment list --compartment-id=${compartment_id} --instance-id=${instance_id})

# get vnic-id for the vnic. Assuming a single vnc here for sample. Assumption is likely wrong given bandwidth requirements.
vnic_id=$(echo $vcn_attachments|jq '.data[0]["vnic-id"]'|sed "s/\"//g")

# get vnic details
vnic_detail=$(oci network vnic get --vnic-id=${vnic_id})

# get the Public IP
public_ip=$(echo $vnic_detail|jq '.data["public-ip"]'|sed "s/\"//g") 

# SSH in to the instance and block until cloud-init is done.
# cloud init is async, this ensures that everything looks good when we build the image out of this instance.
#@TODO : parametrize SSH keys
ssh -o StrictHostKeyChecking=no -i munich opc@${public_ip} 'while [ ! -f /tmp/signal ]; do sleep 2; done'

# @TODO - optionally add a step to verify docker image pull.

# cloud init has finished - docker installed, and images pulled.
# Create the image from the gold instance
image_detail=$(oci compute image create --compartment-id=${compartment_id} --instance-id=${instance_id} --wait-for-state="AVAILABLE")

# get the gold Image Id.
gold_image_id=$(echo ${image_detail}|jq -r -C '.data["id"]')

# create an instance configuration based on the gold instance.


