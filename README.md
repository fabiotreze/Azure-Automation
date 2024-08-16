# Azure-Automation

* Azure Arc SQL Instance - Tag Inheritance script

*Purpose

This repository contains a PowerShell script designed for those who are onboarding SQL machines with Azure Arc and utilizing tags. The purpose of the script is to ensure that the SQL instance associated with an Azure Arc VM inherits the same tags. By default, the Azure Arc SQL Instance may not automatically inherit tags from the Azure Arc VM, which could lead to inconsistencies in resource management.

To address this challenge, the script can be executed through an Azure Automation Account. The script has the following requirements:

Automation Account
The Az.Account and Az.ResourceGraph modules must be installed.
A managed identity must be configured for the Automation Account.

Runbook
You will need to set up a schedule for the runbook.

The script requires the following parameters:
ResourceGroupName
SubscriptionID
tagName

These parameters ensure that the specified tags are applied to the Azure Arc SQL Instance based on the tags of the associated Azure Arc VM.