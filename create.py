import oci
import json
from operator import itemgetter, attrgetter, methodcaller

region='phx'
placement_config = json.loads(open(region+'-placement.json').read())

print(placement_config[0]['availabilityDomain'])




