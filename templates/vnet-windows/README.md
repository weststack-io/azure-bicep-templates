# VNet-Integrated Windows Function App Template

This template deploys a Windows Azure Function App with full VNet integration and private endpoints for enhanced security.

## Resources Deployed

### Compute & Function App

- **Function App**: Windows-based Azure Function App with VNet integration
- **App Service Plan**: Premium v3 (P0v3) plan
- **User Assigned Managed Identity**: For secure access to storage and App Insights

### Networking

- **Virtual Network**: With dedicated subnets for function app and private endpoints
- **Function App Subnet**: Delegated to Microsoft.Web/serverFarms
- **Private Endpoint Subnet**: For storage account private endpoints
- **Private Endpoints**: Separate endpoints for Blob, Table, and Queue storage
- **Private DNS Zones**: For privatelink.blob, privatelink.table, and privatelink.queue

### Storage & Monitoring

- **Storage Account**: Standard LRS with public access disabled, accessible only via private endpoints
- **Application Insights**: For monitoring and telemetry
- **Log Analytics Workspace**: Backend for Application Insights

## Key Features

- ✅ Full VNet integration with dedicated subnet
- ✅ Private endpoints for all storage services (Blob, Table, Queue)
- ✅ Public network access disabled on storage
- ✅ Private DNS zones for name resolution
- ✅ Managed Identity authentication (no storage keys)
- ✅ Route all traffic through VNet (`vnetRouteAllEnabled`)
- ✅ HTTPS only with TLS 1.2 minimum
- ✅ Always On enabled

## Network Architecture

```
VNet (10.0.0.0/16)
├── Function Subnet (10.0.1.0/24)
│   └── Function App (VNet integrated)
└── Private Endpoint Subnet (10.0.2.0/24)
    ├── Blob Private Endpoint
    ├── Table Private Endpoint
    └── Queue Private Endpoint
```

## Parameters

| Parameter                   | Description                        | Default                 |
| --------------------------- | ---------------------------------- | ----------------------- |
| location                    | Azure region                       | Resource group location |
| functionAppRuntime          | Runtime (.NET, Python, Node, etc.) | `dotnet-isolated`       |
| functionAppRuntimeVersion   | Runtime version                    | `8.0`                   |
| vnetAddressPrefix           | VNet CIDR block                    | `10.0.0.0/16`           |
| functionSubnetPrefix        | Function app subnet CIDR           | `10.0.1.0/24`           |
| privateEndpointSubnetPrefix | Private endpoint subnet CIDR       | `10.0.2.0/24`           |

## Deployment

```powershell
.\scripts\Deploy-FunctionApp.ps1 -TemplateName "vnet-windows" -Environment "dev" -ResourceGroupName "rg-myapp-dev"
```

## Security Benefits

1. **Network Isolation**: Storage account is not accessible from the public internet
2. **Private Connectivity**: All storage traffic flows through private endpoints within the VNet
3. **DNS Resolution**: Private DNS zones ensure proper name resolution for storage endpoints
4. **No Storage Keys**: Uses managed identity for authentication
5. **Traffic Control**: All function app traffic can be routed through the VNet

## Use Cases

- Production workloads requiring network isolation
- Compliance requirements for private connectivity
- Integration with on-premises networks via VPN/ExpressRoute
- Controlled egress through firewall appliances
