#!/bin/bash

# set virtualenv
source ~/dev/oci/virtualenv/bin/activate

# optional, can be parametrized
initial_role_tag="streaming_node"
build_tag="2019.01.001"

# parse input
while getopts ":l:h" opt; do
  case ${opt} in
    h )
      echo "Usage: ${0} -l [path]"
      echo "        -l [path] Path to launch template JSON "
      exit 0
      ;;
    l )
      launch_template=$OPTARG
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ -z "${launch_template}" ]
then
   echo "Usage: ${0} -l [path]"
   exit
fi

echo "Starting to provision a gold instance..."
# create an instance based on template. blocking enabled, so that we get the instance details synchronously.
# template used creates only a single vnic for the sample. this is likely inadequate for actual use, however
# the bandwidth for the compute shape is fixed, regardless of the #of vnics.
instance_detail=$(oci compute instance launch --from-json file://${launch_template})

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

cat clone.tpl |jq --arg gold_image_id "$gold_image_id" '.launchDetails["source-details"]["image-id"] = $gold_image_id'\
    |jq --arg initial_role_tag "$initial_role_tag" '.launchDetails["freeform-tags"]["instance_role"] = $initial_role_tag'\
    |jq --arg build_tag "$build_tag" '.launchDetails["freeform-tags"]["build"] = $build_tag'\
    |jq '.launchDetails["display-name"] = "node"'\
    |jq '.launchDetails["create-vnic-details"]["display-name"] = "localnode"'\
    |jq --arg compartment_id "$compartment_id" '.launchDetails["compartment-id"] = $compartment_id' > clone_config.json

echo "Launch config based on gold image created."