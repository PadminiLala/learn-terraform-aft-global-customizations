#!/bin/bash

# Get a list of all available regions
REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# Loop through each region
for REGION in $REGIONS; do
    echo "Checking region: $REGION"
    
    # Get the default VPC ID for the current region
    VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
    
    if [ "$VPC_ID" != "None" ]; then
        echo "Default VPC ID in $REGION: $VPC_ID"

        # Delete Internet Gateways
        IGWS=$(aws ec2 describe-internet-gateways --region $REGION --query "InternetGateways[?Attachments[?VpcId=='$VPC_ID']].InternetGatewayId" --output text)
        for IGW in $IGWS; do
            echo "  Detaching IGW $IGW from $VPC_ID"
            aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW --vpc-id $VPC_ID
            echo "  Deleting IGW $IGW"
            aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW
        done

        # Delete Subnets
        SUBNETS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text)
        for SUBNET in $SUBNETS; do
            echo "  Deleting subnet $SUBNET"
            aws ec2 delete-subnet --region $REGION --subnet-id $SUBNET
        done

        # Delete Route Tables
        ROUTE_TABLES=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[].RouteTableId" --output text)
        for RT in $ROUTE_TABLES; do
            MAIN=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $RT --query "RouteTables[0].Associations[?Main==\`true\`].RouteTableId" --output text)
            if [ -z "$MAIN" ]; then
                echo "  Deleting route table $RT"
                aws ec2 delete-route-table --region $REGION --route-table-id $RT
            fi
        done

        # Delete Network ACLs
        ACLS=$(aws ec2 describe-network-acls --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkAcls[].NetworkAclId" --output text)
        for ACL in $ACLS; do
            DEFAULT=$(aws ec2 describe-network-acls --region $REGION --network-acl-ids $ACL --query "NetworkAcls[0].IsDefault" --output text)
            if [ "$DEFAULT" != "True" ]; then
                echo "  Deleting ACL $ACL"
                aws ec2 delete-network-acl --region $REGION --network-acl-id $ACL
            fi
        done

        # Delete Security Groups
        SGS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[].GroupId" --output text)
        for SG in $SGS; do
            DEFAULT_NAME=$(aws ec2 describe-security-groups --region $REGION --group-ids $SG --query "SecurityGroups[0].GroupName" --output text)
            if [ "$DEFAULT_NAME" != "default" ]; then
                echo "  Deleting security group $SG"
                aws ec2 delete-security-group --region $REGION --group-id $SG
            fi
        done

        # Finally, delete the VPC
        echo "Deleting VPC $VPC_ID"
        aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID
    else
        echo "No default VPC in $REGION."
    fi
done
