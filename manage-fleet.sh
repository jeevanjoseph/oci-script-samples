
#!/bin/bash

# set virtualenv
source ~/dev/oci/virtualenv/bin/activate

# parse input
while getopts ":n:c:a:k:v:p:l:h" opt; do
  case ${opt} in
    h )
      echo "Usage: manage-fleet -n [num] -c [compartment-id] -a [ACTION] -k [TAG KEY] -v [TAG VALUE]"
      echo "        -n [num]     Number of instances to affect"
      echo "        -c [compartment-id] compartment OCID "
      echo "        -a [ACTION] action to perform (START|STOP|TERMINATE|SOFTRESET|SOFTSTOP|RESET) "
      echo "        -k [TAG KEY] tag key for selecting resources "
      echo "        -v [TAG VALUE] tag value for selecting resources "
      echo "        -p [path] Path to placement template  JSON "
      echo "        -l [path] Path to launh template JSON "
      exit 0
      ;;
    n )
        fleet_size=$OPTARG
        ;;
    c )
        compartment_id=$OPTARG
        ;;
    a )
        action=$OPTARG
        ;;
    k )
        tag_key=$OPTARG
        ;;
    v )
        tag_value=$OPTARG
        ;;
    p )
        placement_template=$OPTARG
        ;;
    l )
        launch_template=$OPTARG
        ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ ! -z ${action+x} ]; then
    echo ${fleet_size} ${action} ${tag_key} ${tag_value} ${compartment_id} ${placement_template+x} ${launch_template+x}
fi

if [[ ! -z ${action+x} && ${action} = "PROVISION" ]] ; then
    if [[ ! -z ${fleet_size} && ! -z ${placement_template+x} && ! -z ${launch_template+x} ]] ; then
        python create_nodes.py ${fleet_size} ${placement_template} ${launch_template}
    else
        echo "fleet size, placement_config and launch_templates are required. use -h for help"
    fi
else
    if [[ ! -z ${fleet_size} && ! -z ${action} && ! -z ${tag_key} && ! -z ${tag_value} && ! -z ${compartment_id} ]] ; then
        python apply-action.py ${fleet_size} ${action} ${tag_key} ${tag_value} ${compartment_id}
    else
        echo "fleet size, action, tag_key, tag_value and compartment_id are required. use -h for help"
    fi
fi
    