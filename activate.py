import oci
from operator import itemgetter, attrgetter, methodcaller

compartment_id = "ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma"

config = oci.config.from_file()

managementClient = oci.core.ComputeManagementClient(config)
computeClient = oci.core.ComputeClient(config)
networkClient = oci.core.VirtualNetworkClient(config)

instancePools = managementClient.list_instance_pools(compartment_id).data

# Naively assuming a single instance pool
instance_pool_id = instancePools[0].id

instances = managementClient.list_instance_pool_instances(compartment_id,instance_pool_id).data

for instance in sorted(instances, key=attrgetter('state')):
    computeClient.instance_action(instance.id,"START")

managementClient.start_instance_pool(instance_pool_id)



