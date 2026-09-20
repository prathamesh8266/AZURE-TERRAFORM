terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 5.0"
    }
  }
  backend "azurerm" {
    # will be pupulated usin backend.loca.hcl on terraform init, this is used to seperate out environments (dev,test,prod)
    # Backend settings are supplied during terraform init using -backend-config,
    # allowing each environment to use a separate remote state configuration.
  }
}

provider "azurerm" {
  features {}
}