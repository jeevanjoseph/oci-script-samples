import oci
import sys

if len(sys.argv) != 3:
    raise RuntimeError('Invalid number of arguments provided to the script. Consult the script header for required arguments \nUsage : apply-action [TAGVAL:instance_role] [ACTION:(START|STOP|TERMINATE|SOFTRESET|SOFTSTOP|RESET)]. \n ')  

compartment_id = "ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma"
stop_tag_key = "instance_role"
stop_tag_val= sys.argv[1]
action=sys.argv[2]

config = oci.config.from_file()
computeClient = oci.core.ComputeClient(config)

instances = computeClient.list_instances(compartment_id).data


for instance in instances:
    if stop_tag_key in instance.freeform_tags:
        if instance.freeform_tags[stop_tag_key] == stop_tag_val:
            if action == "TERMINATE":
                computeClient.terminate_instance(instance.id)
                print(action+" submitted on "+instance.display_name)
            else :
                computeClient.instance_action(instance.id, action)
                print(action+" submitted on "+instance.display_name)
