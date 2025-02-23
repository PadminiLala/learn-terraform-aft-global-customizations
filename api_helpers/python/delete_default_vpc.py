import subprocess
import sys
import json

# Function to handle errors
def handle_error(error_code, command):
    print(f"Error occurred while executing: {command}")
    print(f"Error Code: {error_code}")

    # Check if the error is UnauthorizedOperation due to SCP
    if "UnauthorizedOperation" in error_code:
        print("Skipping operation due to explicit deny in SCP.")
        return 0  # Continue the script by returning 0 (no exit)
    else:
        print(f"Exiting script due to error: {error_code}")
        sys.exit(1)  # Exit script for other errors

# Function to run AWS CLI commands and return the result
def run_aws_command(command):
    try:
        result = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
        return result.decode('utf-8')
    except subprocess.CalledProcessError as e:
        return e.output.decode('utf-8')

# Get governed regions from AWS Control Tower
def get_governed_regions(landing_zone_arn):
    command = f"aws controltower get-landing-zone --landing-zone-identifier {landing_zone_arn}"
    output = run_aws_command(command)
    try:
        landing_zone_data = json.loads(output)
        governed_regions = landing_zone_data.get("LandingZone", {}).get("GovernedRegions", [])
        return governed_regions
    except json.JSONDecodeError:
        print("Failed to parse the JSON response.")
        return []

# Get governed regions from Control Tower
landing_zone_arn = "arn:aws:controltower:us-east-1:026090524882:landingzone/180V8I5QW5YG1K47"
governed_regions = get_governed_regions(landing_zone_arn)

# Loop through each governed region
for region in governed_regions:
    print(f"Checking governed region: {region}")
    
    # Get the default VPC ID for the current region
    vpc_id_command = f"aws ec2 describe-vpcs --region {region} --filters 'Name=isDefault,Values=true' --query 'Vpcs[0].VpcId' --output text"
    vpc_id = run_aws_command(vpc_id_command).strip()

    if vpc_id != "None":
        print(f"Default VPC ID in {region}: {vpc_id}")

        # Delete Internet Gateways
        igws_command = f"aws ec2 describe-internet-gateways --region {region} --query 'InternetGateways[?Attachments[?VpcId==`{vpc_id}`]].InternetGatewayId' --output text"
        igws = run_aws_command(igws_command).split()
        
        for igw in igws:
            print(f"  Detaching IGW {igw} from {vpc_id}")
            result = run_aws_command(f"aws ec2 detach-internet-gateway --region {region} --internet-gateway-id {igw} --vpc-id {vpc_id}")
            error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
            if error_code:
                handle_error(error_code[0], f"Detach Internet Gateway {igw}")
                continue
            print(f"  Deleting IGW {igw}")
            result = run_aws_command(f"aws ec2 delete-internet-gateway --region {region} --internet-gateway-id {igw}")
            error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
            if error_code:
                handle_error(error_code[0], f"Delete Internet Gateway {igw}")
                continue

        # Delete Subnets
        subnets_command = f"aws ec2 describe-subnets --region {region} --filters 'Name=vpc-id,Values={vpc_id}' --query 'Subnets[].SubnetId' --output text"
        subnets = run_aws_command(subnets_command).split()
        
        for subnet in subnets:
            print(f"  Deleting subnet {subnet}")
            result = run_aws_command(f"aws ec2 delete-subnet --region {region} --subnet-id {subnet}")
            error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
            if error_code:
                handle_error(error_code[0], f"Delete Subnet {subnet}")
                continue

        # Delete Route Tables
        route_tables_command = f"aws ec2 describe-route-tables --region {region} --filters 'Name=vpc-id,Values={vpc_id}' --query 'RouteTables[].RouteTableId' --output text"
        route_tables = run_aws_command(route_tables_command).split()
        
        for rt in route_tables:
            main_command = f"aws ec2 describe-route-tables --region {region} --route-table-ids {rt} --query 'RouteTables[0].Associations[?Main==`true`].RouteTableId' --output text"
            main = run_aws_command(main_command).strip()
            if not main:
                print(f"  Deleting route table {rt}")
                result = run_aws_command(f"aws ec2 delete-route-table --region {region} --route-table-id {rt}")
                error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
                if error_code:
                    handle_error(error_code[0], f"Delete Route Table {rt}")
                    continue

        # Delete Network ACLs
        acls_command = f"aws ec2 describe-network-acls --region {region} --filters 'Name=vpc-id,Values={vpc_id}' --query 'NetworkAcls[].NetworkAclId' --output text"
        acls = run_aws_command(acls_command).split()
        
        for acl in acls:
            default_command = f"aws ec2 describe-network-acls --region {region} --network-acl-ids {acl} --query 'NetworkAcls[0].IsDefault' --output text"
            default = run_aws_command(default_command).strip()
            if default != "True":
                print(f"  Deleting ACL {acl}")
                result = run_aws_command(f"aws ec2 delete-network-acl --region {region} --network-acl-id {acl}")
                error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
                if error_code:
                    handle_error(error_code[0], f"Delete Network ACL {acl}")
                    continue

        # Delete Security Groups
        security_groups_command = f"aws ec2 describe-security-groups --region {region} --filters 'Name=vpc-id,Values={vpc_id}' --query 'SecurityGroups[].GroupId' --output text"
        security_groups = run_aws_command(security_groups_command).split()
        
        for sg in security_groups:
            default_name_command = f"aws ec2 describe-security-groups --region {region} --group-ids {sg} --query 'SecurityGroups[0].GroupName' --output text"
            default_name = run_aws_command(default_name_command).strip()
            if default_name != "default":
                print(f"  Deleting security group {sg}")
                result = run_aws_command(f"aws ec2 delete-security-group --region {region} --group-id {sg}")
                error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
                if error_code:
                    handle_error(error_code[0], f"Delete Security Group {sg}")
                    continue

        # Finally, delete the VPC
        print(f"Deleting VPC {vpc_id}")
        result = run_aws_command(f"aws ec2 delete-vpc --region {region} --vpc-id {vpc_id}")
        error_code = [line for line in result.splitlines() if "UnauthorizedOperation" in line]
        if error_code:
            handle_error(error_code[0], f"Delete VPC {vpc_id}")
            continue
    else:
        print(f"No default VPC in {region}.")
