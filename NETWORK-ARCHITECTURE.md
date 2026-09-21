# Network boundaries and connections

This diagram shows the resources defined by the Terraform deployments. Boxes inside `vnet-primary` are subnet address spaces. PostgreSQL, Key Vault, Container Registry, Function Apps, and Storage Accounts are Azure managed services outside the VNet; their private endpoints are inside it.

```mermaid
flowchart LR
  subgraph backend["Terraform state resource group: rg-terraform"]
    state["terraformsablob / tfstate container"]
  end

  subgraph workload["Workload resource group: rg-primary (one Azure region)"]
    subgraph vnet["vnet-primary: 10.0.0.0/16"]
      routing(("Azure VNet routing"))
      resolution["VNet DNS resolution"]

      subgraph app["snet-app: 10.0.0.0/22"]
        vms["VM NICs (count)"]
        kvPE["Key Vault private endpoint"]
        acrPE["Registry private endpoint"]
        fnPE["Function App private endpoints"]
        blobPE["Blob private endpoint"]
      end

      subgraph database["snet-database: 10.0.4.0/24"]
        pgPE["PostgreSQL private endpoint"]
      end

      subgraph functions["snet-app-functions: 10.0.5.0/24 (delegated)"]
        fnOutbound["Function App outbound VNet integration"]
      end

      subgraph aks["snet-app-aks: 10.0.8.0/22"]
        aksNodes["AKS node pool"]
      end
    end

    subgraph services["Azure managed services (outside subnets)"]
      vault["Key Vault"]
      registry["Container Registry"]
      fnHost["Function Apps / EP1 plan"]
      postgres["PostgreSQL Flexible Server"]
      blob["Application Storage Account / Blob"]
      fnStorage["Function host storage accounts"]
    end

    dns["Private DNS zones linked to vnet-primary"]
  end

  routing --- vms
  routing --- aksNodes
  routing --- fnOutbound
  routing --- pgPE
  routing --- kvPE
  routing --- acrPE
  routing --- fnPE
  routing --- blobPE

  pgPE -->|Private Link| postgres
  kvPE -->|Private Link| vault
  acrPE -->|Private Link| registry
  fnPE -->|Private Link inbound| fnHost
  blobPE -->|Private Link| blob
  fnHost -->|Outbound integration| fnOutbound
  fnHost -->|Host storage access| fnStorage
  aksNodes -->|Image pulls| acrPE
  dns -. "VNet links and private records" .-> resolution
```

The routing lines mean those subnet addresses can reach each other through the VNet. They do not represent a deployed router, application request, firewall rule, or RBAC grant. AKS nodes use their own subnet because sharing an AKS node subnet with unrelated resources can block cluster operations. The Function integration subnet is separately delegated to `Microsoft.Web/serverFarms` and cannot host the private endpoints.

| Private endpoint | Subnet | Private DNS zone |
| --- | --- | --- |
| PostgreSQL | `snet-database` | `privatelink.postgres.database.azure.com` |
| Key Vault | `snet-app` | `privatelink.vaultcore.azure.net` |
| Container Registry | `snet-app` | `privatelink.azurecr.io` |
| Function Apps | `snet-app` | `privatelink.azurewebsites.net` |
| Application Storage Blob | `snet-app` | `privatelink.blob.core.windows.net` |

The AKS node pool and VM NICs have private addresses in their subnets. Function Apps use `snet-app-functions` for outbound traffic and private endpoints in `snet-app` for inbound traffic. Their separate host storage accounts retain public network access. The application Storage Account has public network access disabled and only its Blob service has a private endpoint. The AKS API endpoint has no private-cluster setting in the current configuration.

The backend storage account in `rg-terraform` is separate from the application Storage Account in `rg-primary`. It stores Terraform state and is not connected to `vnet-primary` by this repo. See [the deployment guide](README.md) for deployment order and inputs, and [the network module](Modules/Network/main.tf) for the subnet and DNS definitions.
