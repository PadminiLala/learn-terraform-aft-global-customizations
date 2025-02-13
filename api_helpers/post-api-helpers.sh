#!/bin/bash

# Function to handle errors
handle_error() {
    ERROR_CODE=$1
    COMMAND=$2
    echo "Error occurred while executing: $COMMAND"
    echo "Error Code: $ERROR_CODE"
    
    # Check if the error is UnauthorizedOperation due to SCP
    if [[ "$ERROR_CODE" == *"UnauthorizedOperation"* ]]; then
        echo "Skipping operation due to explicit deny in SCP."
        return 0  # Continue the script by returning 0 (no exit)
    else
        echo "Exiting script due to error: $ERROR_CODE"
        exit 1  # Exit script for other errors
    fi
}

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
            RESULT=$(aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW --vpc-id $VPC_ID 2>&1)
            ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
            if [[ -n "$ERROR_CODE" ]]; then
                handle_error "$ERROR_CODE" "Detach Internet Gateway $IGW"
                continue
            fi
            echo "  Deleting IGW $IGW"
            RESULT=$(aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW 2>&1)
            ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
            if [[ -n "$ERROR_CODE" ]]; then
                handle_error "$ERROR_CODE" "Delete Internet Gateway $IGW"
                continue
            fi
        done

        # Delete Subnets
        SUBNETS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text)
        for SUBNET in $SUBNETS; do
            echo "  Deleting subnet $SUBNET"
            RESULT=$(aws ec2 delete-subnet --region $REGION --subnet-id $SUBNET 2>&1)
            ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
            if [[ -n "$ERROR_CODE" ]]; then
                handle_error "$ERROR_CODE" "Delete Subnet $SUBNET"
                continue
            fi
        done

        # Delete Route Tables
        ROUTE_TABLES=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[].RouteTableId" --output text)
        for RT in $ROUTE_TABLES; do
            MAIN=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $RT --query "RouteTables[0].Associations[?Main==\`true\`].RouteTableId" --output text)
            if [ -z "$MAIN" ]; then
                echo "  Deleting route table $RT"
                RESULT=$(aws ec2 delete-route-table --region $REGION --route-table-id $RT 2>&1)
                ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
                if [[ -n "$ERROR_CODE" ]]; then
                    handle_error "$ERROR_CODE" "Delete Route Table $RT"
                    continue
                fi
            fi
        done

        # Delete Network ACLs
        ACLS=$(aws ec2 describe-network-acls --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkAcls[].NetworkAclId" --output text)
        for ACL in $ACLS; do
            DEFAULT=$(aws ec2 describe-network-acls --region $REGION --network-acl-ids $ACL --query "NetworkAcls[0].IsDefault" --output text)
            if [ "$DEFAULT" != "True" ]; then
                echo "  Deleting ACL $ACL"
                RESULT=$(aws ec2 delete-network-acl --region $REGION --network-acl-id $ACL 2>&1)
                ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
                if [[ -n "$ERROR_CODE" ]]; then
                    handle_error "$ERROR_CODE" "Delete Network ACL $ACL"
                    continue
                fi
            fi
        done

        # Delete Security Groups
        SGS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[].GroupId" --output text)
        for SG in $SGS; do
            DEFAULT_NAME=$(aws ec2 describe-security-groups --region $REGION --group-ids $SG --query "SecurityGroups[0].GroupName" --output text)
            if [ "$DEFAULT_NAME" != "default" ]; then
                echo "  Deleting security group $SG"
                RESULT=$(aws ec2 delete-security-group --region $REGION --group-id $SG 2>&1)
                ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
                if [[ -n "$ERROR_CODE" ]]; then
                    handle_error "$ERROR_CODE" "Delete Security Group $SG"
                    continue
                fi
            fi
        done

        # Finally, delete the VPC
        echo "Deleting VPC $VPC_ID"
        RESULT=$(aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID 2>&1)
        ERROR_CODE=$(echo "$RESULT" | grep -o 'UnauthorizedOperation.*')
        if [[ -n "$ERROR_CODE" ]]; then
            handle_error "$ERROR_CODE" "Delete VPC $VPC_ID"
            continue
        fi
    else
        echo "No default VPC in $REGION."
    fi
done
