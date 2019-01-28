
#!/bin/bash

# set virtualenv
source ~/dev/oci/virtualenv/bin/activate

if [ -p /dev/stdin ]; then
    input_json=$(cat)
    data=$(echo ${input_json}|jq -r '.data'&>/dev/null) 
        if [[ -n ${data} ]] ; then
            for ids in $(echo ${data}|jq '.[].id')
            do
                echo "[ ${ids} ]"
            done
        else
            echo "Unreadable data was piped to this script. Input from stdin is expected to be valid OCI API JSON."
            exit 1
        fi
	 
fi

# parse input
while getopts ":n:c:a:k:v:p:l:h" opt; do
  case ${opt} in
    h )
      echo "Usage: ${0} -n [num] -c [compartment-id] -a [ACTION] -k [TAG KEY] -v [TAG VALUE]"
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
        compartment_id=$(jq -r '.launchDetails["compartment-id"]' ${launch_template})
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

# check options and delegate.
# node creation is handled by one script, and nod eactions by another.
# these can be unified.
if [[ -n ${action+x} && ${action} = "PROVISION" ]] ; then
    if [[ -n ${fleet_size} && -n ${placement_template+x} && -n ${launch_template+x} ]] ; then
        python create_nodes.py ${fleet_size} ${placement_template} ${launch_template}
    else
        echo "fleet size, placement_config and launch_templates are required. use -h for help"
    fi
else
    if [[ -n ${fleet_size} && -n ${action} && -n ${tag_key} && -n ${tag_value} && -n ${compartment_id} ]] ; then
        python apply-action.py ${fleet_size} ${action} ${tag_key} ${tag_value} ${compartment_id}
    else
        echo "fleet size, action, tag_key, tag_value and compartment_id are required. use -h for help"
    fi
fi
    