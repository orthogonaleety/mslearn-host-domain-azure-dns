#!/bin/bash

#the Resource group name to be created and used
RgName='Exercise-CreateAliasRecords_for_AzureDNS'
#the location to be used
Location='eastus'

#Inform of Location to be used, and prompt for an opportunity to abort.
echo
echo '--------------------------------------------------------------------------'
echo "Resources will be created with location '$Location'."
echo 'You can change this by editing the setup.sh with `nano ./setup.sh`'
echo
read -n1 -r -p "Press 'y' to proceed or any other key to abort: " answer
echo
if [[ $answer != [Yy] ]]; then
  echo "Aborted."
  exit 1
fi
echo

#Availability of SizeSKUs can change, in which case alter the following. 
VMSizeSKU='Standard_B1s'
#For a list of availabel SKUs run `az vm list-skus --location eastus --resource-type virtualMachines --output table`
#Note that costs can vary.
#To browse costs you use either https://azure.microsoft.com/en-us/pricing/calculator/, or browse options using 'Create virtual machine' in the Azure portal.

date

# Create a Resource group to tidy the excercise's resources
echo '------------------------------------------'
echo 'Creating the resource group'
az group create --name $RgName --location $Location

# Create a Virtual Network for the VMs
echo '------------------------------------------'
echo 'Creating a Virtual Network for the VMs'
az network vnet create \
    --resource-group $RgName \
    --location $Location \
    --name bePortalVnet \
    --subnet-name bePortalSubnet 

# Create a Network Security Group
echo '------------------------------------------'
echo 'Creating a Network Security Group'
az network nsg create \
    --resource-group $RgName \
    --name bePortalNSG \
    --location $Location

az network nsg rule create -g $RgName --nsg-name bePortalNSG -n AllowAll80 --priority 101 \
                            --source-address-prefixes 'Internet' --source-port-ranges '*' \
                            --destination-address-prefixes '*' --destination-port-ranges 80 --access Allow \
                            --protocol Tcp --description "Allow all port 80 traffic"


# Create the NIC
for i in `seq 1 2`; do
  echo '------------------------------------------'
  echo 'Creating webNic'$i
  az network nic create \
    --resource-group $RgName \
    --name webNic$i \
    --vnet-name bePortalVnet \
    --subnet bePortalSubnet \
    --network-security-group bePortalNSG \
    --location $Location
done 

# Create an availability set
echo '------------------------------------------'
echo 'Creating an availability set'
az vm availability-set create \
    --resource-group $RgName \
    --name portalAvailabilitySet

# Create 2 VM's from a template
for i in `seq 1 2`; do
    echo '------------------------------------------'
    echo 'Creating webVM'$i
    az vm create \
        --admin-username azureuser \
        --resource-group $RgName \
        --name webVM$i \
        --nics webNic$i \
        --location $Location \
        --image Ubuntu2204 \
        --size $VMSizeSKU \
        --availability-set portalAvailabilitySet \
        --generate-ssh-keys \
        --custom-data cloud-init.txt
done

# Done
echo '--------------------------------------------------------'
echo '             VM Setup Completed'
echo '--------------------------------------------------------'

echo '--------------------------------------------------------'
echo '             Starting Load Balancer Deploy'
echo '--------------------------------------------------------'


    az network public-ip create \
      --resource-group $RgName \
      --location $Location \
      --allocation-method Static \
      --name myPublicIP \
      --sku Standard

   az network lb create \
      --resource-group $RgName \
      --name myLoadBalancer \
      --public-ip-address myPublicIP \
      --frontend-ip-name myFrontEndPool \
      --backend-pool-name myBackEndPool \
      --sku Standard

  az network lb probe create \
     --resource-group $RgName \
     --lb-name myLoadBalancer \
     --name myHealthProbe \
     --protocol tcp \
     --port 80

  az network lb rule create \
      --resource-group $RgName \
      --lb-name myLoadBalancer \
      --name myHTTPRule \
      --protocol tcp \
      --frontend-port 80 \
      --backend-port 80 \
      --frontend-ip-name myFrontEndPool \
      --backend-pool-name myBackEndPool

  az network nic ip-config update \
      --resource-group $RgName \
      --nic-name webNic1 \
      --name ipconfig1 \
      --lb-name myLoadBalancer \
      --lb-address-pools myBackEndPool

  az network nic ip-config update \
      --resource-group $RgName \
      --nic-name webNic2 \
      --name ipconfig1 \
      --lb-name myLoadBalancer \
      --lb-address-pools myBackEndPool

  az network public-ip show \
      --resource-group $RgName \
      --name myPublicIP \
      --query [ipAddress] \
      --output tsv

echo '--------------------------------------------------------'
echo '  Load balancer deployed to the IP Address shown above'
echo '--------------------------------------------------------'

echo '-----------------------------------------------------------------'
echo '  Remember to Clean up your resources later.'
echo "  These can be found under group '$RgName'"
echo '  The portal allows convenient use of the 'force' option.'
echo '-----------------------------------------------------------------'










