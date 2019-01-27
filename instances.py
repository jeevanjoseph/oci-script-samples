import oci
from operator import itemgetter, attrgetter, methodcaller

compartment_id = "ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma"

config = oci.config.from_file()

computeClient = oci.core.ComputeClient(config)
networkClient = oci.core.VirtualNetworkClient(config)

instance_list = computeClient.list_instances(compartment_id).data
vnic_attachments = computeClient.list_vnic_attachments(compartment_id).data

for instance in sorted(instance_list, key=attrgetter('id')):
    for vnic_attachment in vnic_attachments:
        if (vnic_attachment.instance_id == instance.id) and (vnic_attachment.lifecycle_state == "ATTACHED"):
            vnic = networkClient.get_vnic(vnic_attachment.vnic_id).data
            print(
                instance.id + " - [" + instance.lifecycle_state + "] (" + vnic.public_ip + ")")
