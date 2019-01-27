import oci
import json
import sys
import time

if len(sys.argv) != 3:
    raise RuntimeError('Invalid number of arguments provided to the script. Consult the script header for required arguments \nUsage : create [count: number of instances] [region-code: ex:phx]. \n ')  

config = oci.config.from_file()
computeClient = oci.core.ComputeClient(config)
networkClient = oci.core.VirtualNetworkClient(config)

region = sys.argv[2]
instance_count = int(sys.argv[1])
launch_config_list = []
placement_config = json.loads(open(region+'-placement.json').read())
instance_template = json.loads(open('clone_config.json').read())


for idx in range(instance_count):
    ad_config = placement_config[idx % len(placement_config)]
    launch_instance_details = oci.core.models.LaunchInstanceDetails(
        compartment_id = instance_template["launchDetails"]["compartment-id"],
        availability_domain = ad_config["availabilityDomain"],
        shape = instance_template["launchDetails"]["shape"],
        display_name = instance_template["launchDetails"]["display-name"]+str(idx),
        freeform_tags = instance_template["launchDetails"]["freeform-tags"],
        source_details=oci.core.models.InstanceSourceViaImageDetails(
            image_id = instance_template["launchDetails"]["source-details"]["image-id"]
        ),
        create_vnic_details = oci.core.models.CreateVnicDetails(
            subnet_id = ad_config["primarySubnetId"],
            display_name = instance_template["launchDetails"]["create-vnic-details"]["display-name"]+str(idx),
            assign_public_ip = instance_template["launchDetails"]["create-vnic-details"]["assign-public-ip"]
        )
    )
    launch_config_list.append(computeClient.launch_instance(launch_instance_details,retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY))
    print(launch_config_list[len(launch_config_list)-1].data)
    


