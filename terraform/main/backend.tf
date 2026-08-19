terraform {
  backend "s3" {
    bucket       = "project-bedrock-tfstate-alt-soe-tin-025-0324"
    key          = "state/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
