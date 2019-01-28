import oci
import sys
import time
from collections import defaultdict

if len(sys.argv) != 6:
    raise RuntimeError('Invalid number of arguments provided to the script.\n'+
                    'Consult the script header for required arguments \n'+
                    'Usage : apply-action [count : number of instances] [ACTION:(START|STOP|TERMINATE|SOFTRESET|SOFTSTOP|RESET)]. \n ')  

desired_count= int(sys.argv[1])
action=sys.argv[2]
tag_key=sys.argv[3]
tag_val=sys.argv[4]
compartment_id = sys.argv[5]
#compartment_id = "ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma"

instances  =[]

config = oci.config.from_file()
computeClient = oci.core.ComputeClient(config)
networkClient = oci.core.VirtualNetworkClient(config)

#---------
# Get the instance list.
# NOTE : APIs are idempotent, you can ask a RUNNING Isntance to be STARTED -> nothing happens.
#           This is simply for avoiding issues like, a running instance being TERMINATED.
#           A better way to go about this may be to use freeform tags.
# START, TERMINATE - valid on "STOPPED" instances.
# STOP, SOFTSTOP, RESET, SOFTRESET is valid on "RUNNING" instances
# @TODO : not all cases handled.
#---------
if action == 'START' or action == 'TERMINATE':
    instances = computeClient.list_instances(compartment_id,lifecycle_state="STOPPED").data
elif action == 'LIST':
        instances = computeClient.list_instances(compartment_id).data
        desired_count=len(instances)
        vnic_attachments = computeClient.list_vnic_attachments(compartment_id).data
else :
    instances = computeClient.list_instances(compartment_id,lifecycle_state="RUNNING").data
#---------
# Filter instances based on tag
#---------
filtered_instances = list(filter(lambda ins: defaultdict(str,ins.freeform_tags)[tag_key] == tag_val,instances))

# Check if there are enough instances to apply action.
if desired_count > len(filtered_instances) :
    #print('Requested '+action+' on '+str(desired_count)+' instances, but only '+str(len(filtered_instances))+' instances available.')
    desired_count = len(filtered_instances)

#---------
# Apply action on instances.
# @TODO distribute action across ADs.
#---------
for idx in range(desired_count):
    instance = filtered_instances[idx]
    if action == 'TERMINATE':
        computeClient.terminate_instance(instance.id,retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        print(action+" submitted on "+instance.display_name)
    elif action == 'LIST':
        for vnic_attachment in vnic_attachments:
            if (vnic_attachment.instance_id == instance.id) and (vnic_attachment.lifecycle_state == "ATTACHED"):
                vnic = networkClient.get_vnic(vnic_attachment.vnic_id).data
                print(
                    instance.id + "|" + instance.lifecycle_state + "|" + vnic.public_ip + "|")
    else:
        computeClient.instance_action(instance.id, action,retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        print(action+" submitted on "+instance.display_name)


        
                

