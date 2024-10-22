
provider "aws" {
  region = "us-east-1"
  alias  = "target"

  # Set up the provider to assume a role in the target account
  assume_role {
    role_arn = "arn:aws:iam::026090524882:role/AWSAFTExecution" # Replace with your target account ID and role name
  }
}