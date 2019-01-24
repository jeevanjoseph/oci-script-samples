import oci


config = oci.config.from_file()

computeClient = oci.core.ComputeClient(config)
networkClient = oci.core.VirtualNetworkClient(config)

instance_list = computeClient.list_instances("ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma").data
vnic_attachments = computeClient.list_vnic_attachments("ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma").data

for instance in instance_list:
    for vnic_attachment in vnic_attachments:
        if vnic_attachment.instance_id == instance.id:
            vnic = networkClient.get_vnic(vnic_attachment.vnic_id).data
            print(instance.id +" - ["+ instance.lifecycle_state +"] ("+ vnic.public_ip +")")


