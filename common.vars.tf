/* ==== common vars ==== */
# some, like region, are common to all workspaces and have a default set
# any that should vary between workspaces should have default mapped to workspaces (e.g. dev)
variable "region" {
  default = "eu-central-1"
}

variable "default_tags" {
  default = {
    "terraform" = "true"
    "Project"   = "cloud_native_search"
    "createdBy" = "Accenture Architecture"
    "Name"      = "Cloud Native Search"
  }
}

/* === Workspace Variables === */
variable "env" {
  default = {
    dev  = "dev"
    test = "test"
    qa   = "qa"
  }
}

variable "account_name" {
  default = {
    dev  = "nonprod"
    test = "test"
    qa   = "qa"
  }
}

variable "account_number" {
  default = {
    dev = "123456789012"

    #    test = ""
    #    qa   = ""
  }
}

variable "state_bucket_name" {
  default = {
    dev  = "terraform-state-lock-cloud-native-search-dev"
    test = "terraform-state-lock-cloud-native-search-test"
    qa   = "terraform-state-lock-cloud-native-search-qa"
  }
}

variable "application_shared_bucket_name" {
  default = {
    dev  = "cloud-native-search-dev"
    test = "cloud-native-search-test"
    qa   = "cloud-native-search-qa"
  }
}

/* === API Gateways === */
variable "api_gateway_title" {
  default = {
    dev  = "search_apigw_dev"
    test = "search_apigw_test"
    qa   = "search_apigw_qa"
  }
}
