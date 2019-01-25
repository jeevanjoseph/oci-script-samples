#!/bin/bash

source ~/dev/oci/virtualenv/bin/activate

while getopts ":n:r:t:s:" opt; do
  case $opt in
    n)
      displayName="\"display-name\" == '${OPTARG}'"
      ;;
    r) 
      region="\"region\" == '${OPTARG}'"
      ;;
    t)
      tag="\"display-name\" == '${OPTARG}'"
      ;;
    s)
      state="\"lifecycle-state\" == '${OPTARG}'"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done


oci compute instance list --compartment-id=ocid1.compartment.oc1..aaaaaaaa4vxl6yyvfcumwutejntiu3tzcwacbpgdqndh3kct5i65ahvz7oma --query "data[?${displayName} || ${region} || ${state}]"

