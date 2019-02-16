#!/bin/bash
#
# Requirements
# - Bash shell
# - OCI CLI installed and configured
#   https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm
# - "jq" package (usually installable via `$sudo yum install jq -y`)
#
# Scope
# - This script is not meant to be quick. We've chosen accuracy over performance.
# - This version ignores resources inside the root compartment
# - Resource types captured:
# Compartments, Policies, VM instances, VNIC attachments, VCNs, Subnets, Route Tables, Security Lists, Load Balancers, DRGs, DRG attachments, CPEs, IPSec connections, Virtual Circuits
# 

# format subtitles for each resource type under the tenancy, for better legibility
printTitle() {
	title=$1; str=-; num="80"
	titlelength=`echo -n $title | wc -c`
	repeat=$(expr $num - $titlelength)
	v=$(printf "%-${repeat}s" "$str")
	printf "$title"
	echo "${v// /$str}"
}

# Compartments
for compID in `oci iam compartment list --all | jq -r '.data[] | .id +" "+."lifecycle-state"' | grep "ACTIVE" | awk '{print $1}'`
do
    compID=`oci iam compartment get --compartment-id $compID | jq -r '[.data.id]|.[]'`
    compName=`oci iam compartment get --compartment-id $compID | jq -r '[.data.name]|.[]'`
    printf "\n\nCOMPARTMENT $compName * * * * * * \n"
    # Policies
    printTitle "Policies ($compName)"
    iamPolicyIDs=`oci iam policy list --all --compartment-id $compID | jq -r '[.data[].id]|.[]'`
    oci network cpe list --compartment-id $compID

    # Instances
    printTitle "Virtual Machines ($compName)"
    instanceIDs=`oci compute instance list --compartment-id $compID | jq -r '[.data[].id]|.[]'`
    if [ ! -z "$instanceIDs" ]
    then
        totalInstances=`exec echo "${instanceIDs[@]}" | wc -l | sed 's/ //g'`
        echo "$totalInstances Virtual Machines (VMs)"
        for instanceID in $instanceIDs
        do
            instanceName=`oci compute instance get --instance-id $instanceID | jq -r '[.data."display-name"]|.[]'`
            printTitle "VM instance $instanceName"
            oci compute instance get --instance-id $instanceID
            # VNIC attachments
            printTitle "VNIC attachment(s) for $instanceName"
            oci compute vnic-attachment list --instance-id $instanceID --compartment-id $compID
        done          
    fi

    # VCNs
    printTitle "Virtual Cloud Networks ($compName)"
    vcnIDs=`oci network vcn list --compartment-id $compID | jq -r '[.data[].id]|.[]'`
    if [ ! -z "$vcnIDs" ]
    then
        totalInstances=`exec echo "${vcnIDs[@]}" | wc -l | sed 's/ //g'`
        echo "$totalInstances VCN instances"
        for vcnID in $vcnIDs
        do
            vcnName=`oci network vcn get --vcn-id $vcnID | jq -r '[.data."display-name"]|.[]'`
            printTitle "VCN $vcnName ($compName)"            
            oci network vcn get --vcn-id $vcnID

            # Subnets
            printTitle "Subnets for VCN $vcnName ($compName)"
            for subnetID in `oci network subnet list --compartment-id $compID --vcn-id $vcnID | jq -r '[.data[].id]|.[]'`
            do  
                subnetName=`oci network subnet get --subnet-id $subnetID | jq -r '[.data."display-name"]|.[]'`
                printTitle "Subnet $subnetName ($compName)"
                oci network subnet get --subnet-id $subnetID 
            done # Subnets
        
            # Route table
            printTitle "Route Tables for VCN $vcnName ($compName)"
            for routeTableID in `oci network route-table list --compartment-id $compID --vcn-id $vcnID | jq -r '[.data[].id]|.[]'`
            do
                routeTableName=`oci network route-table get --rt-id $routeTableID | jq -r '[.data."display-name"]|.[]'`
                printTitle "Route Table $routeTableName ($compName)"
                oci network route-table get --rt-id $routeTableID
            done # Route Tables

            # Security Lists
            printTitle "Security Lists for VCN $vcnName ($compName)"
            for securityListID in `oci network security-list list --compartment-id $compID --vcn-id $vcnID | jq -r '[.data[].id]|.[]'`
            do
                securityListName=`oci network security-list get --security-list-id $securityListID | jq -r '[.data."display-name"]|.[]'`
                printTitle "Security List $routeTableName ($compName)"
                oci network security-list get --security-list-id $securityListID
            done # Security Lists

        done # VCNs
    fi

    # DRGs
    printTitle "DRGs ($compName)"
    oci network drg list --compartment-id $compID 

    # DRG Attachments
    printTitle "DRG Attachments ($compName)"
    oci network drg-attachment list --compartment-id $compID

    # CPEs
    printTitle "CPEs ($compName)"
    oci network cpe list --compartment-id $compID 

    # IPSec Connections
    printTitle "IPSec connections ($compName)"
    oci network ip-sec-connection list --compartment-id $compID

    # Virtual Circuits-
    printTitle "Virtual Circuits ($compName)"
    oci network virtual-circuit list --compartment-id $compID

    # Load Balancers
    printTitle "Load Balancers ($compName)"
    for lbID in `oci lb load-balancer list --compartment-id $compID | jq -r '[.data[].id]|.[]'`
    do
        lbName=`oci lb load-balancer get --load-balancer-id $lbID | jq -r '[.data."display-name"]|.[]'`
        echo " Load Balancer $lbName "
        oci lb load-balancer get --load-balancer-id $lbID
    done
done