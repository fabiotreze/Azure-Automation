# Azure-Automation

## Azure Arc SQL Instance - Tag Inheritance script 

## Purpose 

This repository contains a PowerShell script called **Azure Arc SQL Instance - Tag Inheritance** script designed for those who are onboarding SQL machines with Azure Arc and utilizing tags. The purpose of the script is to ensure that the SQL instance associated with an Azure Arc VM inherits the same tags. By default, the Azure Arc SQL Instance may not automatically inherit tags from the Azure Arc VM, which could lead to inconsistencies in resource management.</br>
</br>
To address this challenge, the script can be executed through an Azure Automation Account. The script has the following requirements:</br>
</br>
Automation Account</br>
The **Az.Account** and **Az.ResourceGraph** modules must be installed.</br>
A managed identity must be configured for the Automation Account.</br>
</br>
Runbook</br>
You will need to set up a schedule for the runbook.</br>
</br>
The script requires the following parameters:</br>
**ResourceGroupName**</br>
**SubscriptionID**</br>
**tagName**</br>
</br>
These parameters ensure that the specified tags are applied to the Azure Arc SQL Instance based on the tags of the associated Azure Arc VM.
