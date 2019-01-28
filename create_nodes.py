import oci
import json
import sys
import time

#------------
# Check args
# @TODO : use  a better module for parsing args to handle UNIX and GNU style args
#------------
if len(sys.argv) != 4:
    raise RuntimeError('Invalid number of arguments provided to the script.\n'+
                        'Consult the script header for required arguments.\n'+
                        'Usage : create [count: number of instances] [region-code: ex:phx]. \n')  

instance_count = int(sys.argv[1])
placement = sys.argv[2]
launch_template = sys.argv[3]

#------------
# Setup OCI module and config. Using the default profile implicitly
# Create clients using the config
#------------
config        = oci.config.from_file()
computeClient = oci.core.ComputeClient(config)
networkClient = oci.core.VirtualNetworkClient(config)

#------------
# Get the launch config and placement config for launching instances.
#------------
launch_config_list  = []
placement_config    = json.loads(open(placement).read())
instance_template   = json.loads(open(launch_template).read())

#------------
# Start provisioning the instances
#   The instances are placed based on the placement config, in round robin by default.
#   The launch config is copied over from the one generated by the gold master script.
#   Small tweaks for the display name are made, but otherwise based on the launch config.
#   NOTE : Retry strategy used in the call to `launch_instance`.
#          A retry strategy ensures that the code is able to deal with API rate limits.
#          The default strategy used here uses an exponential backoff policy, but a
#          RetryStrategyBuilder is also provided to customize this behaviour and build 
#          custom retry strategies.           
for idx in range(instance_count):
    ad_config = placement_config[idx % len(placement_config)]
    # Customize the launch config
    launch_instance_details = oci.core.models.LaunchInstanceDetails(
        compartment_id      = instance_template["launchDetails"]["compartment-id"],
        availability_domain = ad_config["availabilityDomain"],
        shape               = instance_template["launchDetails"]["shape"],
        display_name        = instance_template["launchDetails"]["display-name"]+str(idx),
        freeform_tags       = instance_template["launchDetails"]["freeform-tags"],
        source_details      = oci.core.models.InstanceSourceViaImageDetails(
            image_id = instance_template["launchDetails"]["source-details"]["image-id"]
        ),
        create_vnic_details = oci.core.models.CreateVnicDetails(
            subnet_id           = ad_config["primarySubnetId"],
            display_name        = instance_template["launchDetails"]["create-vnic-details"]["display-name"]+str(idx),
            assign_public_ip    = instance_template["launchDetails"]["create-vnic-details"]["assign-public-ip"]
        )
    )
    # Launh the instance and track the instnace IDs in the list.
    # NOTE the use of the RetryStrategy.
    launch_config_list.append(
        computeClient.launch_instance(
            launch_instance_details,retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY))
    print(launch_config_list[len(launch_config_list)-1].data)
    


