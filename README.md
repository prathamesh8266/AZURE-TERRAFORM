# Azure Terraform deployments

`procurement.bash` discovers every `Infrastructure/*` directory containing `.tf` files. It initializes, validates, plans, and asks for `APPLY` before applying the selected deployment. Each directory has its own backend state key.

Before the first run on a new checkout, copy `backend.local.hcl.example` to `backend.local.hcl` and set the existing backend resource group, storage account, and container. The script supplies the state key as `resources/<deployment-folder-in-lowercase>/terraform.tfstate`; for example, `Resource-Group` uses `resources/resource-group/terraform.tfstate` and `PostgreSQL` uses `resources/postgresql/terraform.tfstate`. Each deployment folder has one state file for all resources in that root, including its child modules and `for_each`/`count` instances.

See [Network boundaries and connections](NETWORK-ARCHITECTURE.md) for the VNet, subnet, private endpoint, and DNS diagram.

Deploy in this order:

1. `Resource-Group` (`rg-primary`, default region `indiasouthcentral`)
2. `Network` (`vnet-primary`, app/database/Function integration subnets, and private DNS zones)
3. `Container-Registry`
4. `AKS`, `PostgreSQL`, `Key-Vault`, `Function-App`, and `Virtual-Machines` as needed
5. `Storage-Account` after `Network` (or after the other app resources)

| Subnet | Address range | Resources using it |
| --- | --- | --- |
| `snet-app` | `10.0.0.0/22` | VM NICs and private endpoints for Key Vault, Container Registry, Function Apps, and the storage account's Blob service |
| `snet-database` | `10.0.4.0/24` | PostgreSQL Flexible Server private endpoint |
| `snet-app-functions` | `10.0.5.0/24` | Delegated `Microsoft.Web/serverFarms` subnet for Function App outbound VNet integration |
| `snet-app-aks` | `10.0.8.0/22` | AKS nodes only |

Managed services such as PostgreSQL, Key Vault, Container Registry, Function Apps, and Storage Accounts are not deployed directly into a subnet. Their private endpoints provide inbound private IPs; Function Apps also use the delegated subnet for outbound access. `AKS` reads the registry created in step 3. Key Vault access requires an appropriate RBAC role assignment for the caller; this deployment does not grant one. VMs have private IPs only. Function Apps have host resources and configuration, but no function code is deployed by Terraform. Their supporting storage accounts retain public network access. The separate `Storage-Account` deployment exposes its Blob service privately and disables public network access; its File, Queue, and Table services have no private endpoints.

The separate storage account is for application data. Terraform state continues to use the existing backend account configured in `backend.local.hcl`. Its resource group (`rg-terraform`) is intentionally separate from the workload resource group (`rg-primary`). Every workload deployment gets its region from `rg-primary`; only the Resource Group root sets the region.

Defaults create one AKS node, two Function Apps (`api` and `worker`) through `for_each`, and two Linux VMs through `count`. Private endpoints require a Premium Container Registry and an Elastic Premium (`EP1`) Function plan; these cost more than the earlier Basic registry and Consumption plan. Review each plan and Azure SKU availability before applying.

Required inputs:

- Override the Resource Group's default `indiasouthcentral` location with its existing `local.auto.tfvars` or `TF_VAR_location` if another region is intended.
- Set `TF_VAR_administrator_password` before deploying `PostgreSQL`.
- Set `TF_VAR_ssh_public_key` before deploying `Virtual-Machines`.
- Keep `TF_VAR_name_prefix` consistent across deployments if overriding the default `primary`; AKS looks up the registry using this prefix.

Example in Bash:

```bash
read -rsp 'PostgreSQL password: ' TF_VAR_administrator_password
printf '\n'
export TF_VAR_administrator_password
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
bash procurement.bash
```

The PostgreSQL administrator password and Function App storage access keys are held in Terraform state. Protect the configured state container and avoid committing variable files or state.
