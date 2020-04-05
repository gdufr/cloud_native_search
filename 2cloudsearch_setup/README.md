The cloudsearch domain is defined in cloudsearch.resource.tf

Terraform does not currently have a cloudsearch resource type, so the setup is done by a null_resource that executes a series of aws cli commands

