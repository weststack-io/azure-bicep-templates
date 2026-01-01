# Azure Bicep Infrastructure Templates

A collection of production-ready Bicep templates for deploying Azure resources, starting with Function Apps on isolated App Service Plans.

## Why This Exists

Azure Bicep documentation is often inconsistent and can be difficult to piece together into a working deployment. API versions change, properties get deprecated, and examples in the docs don't always reflect what actually works. This repository exists to capture **tested, working combinations** of Azure resources and configuration so they can be reliably reused.

The goal is to keep these templates up to date as Bicep and Azure APIs evolve, and to expand the collection over time with additional resource types and resource combinations beyond what's currently here.

## What's Included

Currently, the templates cover **Azure Function Apps using isolated (Premium v3) App Service Plans**, with variants for Windows/Linux and with/without VNet integration. All templates include managed identity authentication, monitoring, and security best practices.

## 📁 Project Structure

```
BicepInfraResourceDeployTemplates/
├── templates/
│   ├── basic-windows/        # Basic Windows Function App
│   │   ├── main.bicep
│   │   ├── parameters.dev.json
│   │   └── README.md
│   ├── basic-linux/          # Basic Linux Function App
│   │   ├── main.bicep
│   │   ├── parameters.dev.json
│   │   └── README.md
│   ├── vnet-windows/         # VNet-integrated Windows Function App
│   │   ├── main.bicep
│   │   ├── parameters.dev.json
│   │   └── README.md
│   └── vnet-linux/           # VNet-integrated Linux Function App
│       ├── main.bicep
│       ├── parameters.dev.json
│       └── README.md
├── scripts/
│   └── Deploy-FunctionApp.ps1  # PowerShell deployment script
├── main.bicep                   # Original working template
└── README.md                    # This file
```

## 🚀 Available Templates

### 1. Basic Windows Function App (`basic-windows`)

A straightforward Windows-based function app deployment with:

- Premium v3 App Service Plan
- Optimized for .NET workloads
- Managed Identity for storage access
- Application Insights monitoring
- No network isolation

**Best for:** Development environments, simple workloads, getting started

### 2. Basic Linux Function App (`basic-linux`)

A Linux container-based function app deployment with:

- Premium v3 App Service Plan for Linux
- Managed Identity for storage access
- Application Insights monitoring
- Optimized for Python/Node.js workloads

**Best for:** Python or Node.js workloads, containerized applications

### 3. VNet-Integrated Windows Function App (`vnet-windows`)

Enterprise-grade Windows function app with network isolation:

- VNet integration with dedicated subnet
- Private endpoints for storage (Blob, Table, Queue)
- Private DNS zones
- No public storage access
- Full traffic routing through VNet

**Best for:** Production workloads, compliance requirements, enterprise security

### 4. VNet-Integrated Linux Function App (`vnet-linux`)

Enterprise-grade Linux function app with network isolation:

- VNet integration with dedicated subnet
- Private endpoints for storage (Blob, Table, Queue)
- Private DNS zones
- No public storage access
- Container-based hosting with network security

**Best for:** Production Python/Node.js workloads with strict security requirements

## 🔧 Prerequisites

- **Azure PowerShell Az module**: Install with `Install-Module -Name Az -AllowClobber -Scope CurrentUser`
- **Azure Subscription**: Active Azure subscription with appropriate permissions
- **Bicep CLI**: Installed automatically with Azure CLI or download separately
  - **Note:** If you installed Bicep using the Azure CLI, you may need to add `%USERPROFILE%\.Azure\bin` to your system or user PATH environment variables on Windows
- **PowerShell 7+**: Recommended for cross-platform support

## 📖 Quick Start

### 1. Clone or Download This Repository

```powershell
cd path/to/BicepInfraResourceDeployTemplates
```

### 2. Sign in to Azure

```powershell
Connect-AzAccount
```

### 3. Deploy a Template

```powershell
# Basic Windows deployment
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "basic-windows" `
    -Environment "dev" `
    -ResourceGroupName "rg-myapp-dev"
    -Location "	centralus"

# VNet-enabled Linux deployment
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "vnet-linux" `
    -Environment "prod" `
    -ResourceGroupName "rg-myapp-prod" `
    -Location "westus2"

# Validation only (WhatIf mode)
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "basic-windows" `
    -Environment "dev" `
    -ResourceGroupName "rg-test" `
    -WhatIf
```

## 🎯 Deployment Script Parameters

| Parameter           | Required | Description                     | Example                                |
| ------------------- | -------- | ------------------------------- | -------------------------------------- |
| `TemplateName`      | ✅       | Template to deploy              | `basic-windows`, `vnet-linux`          |
| `Environment`       | ✅       | Environment name                | `dev`, `test`, `prod`                  |
| `ResourceGroupName` | ✅       | Target resource group           | `rg-myapp-dev`                         |
| `Location`          | ❌       | Azure region                    | `eastus` (default)                     |
| `SubscriptionId`    | ❌       | Azure subscription ID           | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AppName`           | ❌       | Custom function app name        | `my-custom-func-app`                   |
| `ResourceToken`     | ❌       | Custom naming token             | `mytoken123`                           |
| `WhatIf`            | ❌       | Validation mode (no deployment) | Switch parameter                       |

## � Alternative: Azure CLI Deployment

If the PowerShell script isn't working or you prefer using Azure CLI, you can deploy directly using the `az deployment group create` command.

### Basic Deployment with Azure CLI

```powershell
# Navigate to the template folder
cd templates\basic-windows

# Deploy using Azure CLI
az deployment group create `
  --resource-group rg-myapp-dev `
  --template-file main.bicep `
  --parameters functionAppRuntime=dotnet-isolated `
               functionAppRuntimeVersion=8.0 `
               appName=myapp-func-dev
```

### Deployment with Debug Output

If you need to troubleshoot deployment issues, add the `--debug` flag:

```powershell
az deployment group create `
  --resource-group rg-myapp-dev `
  --template-file main.bicep `
  --parameters functionAppRuntime=dotnet-isolated `
               functionAppRuntimeVersion=8.0 `
               appName=myapp-func-dev `
  --debug
```

### Using Parameter Files

You can also use parameter files instead of inline parameters:

```powershell
# Deploy using a parameter file
az deployment group create `
  --resource-group rg-myapp-dev `
  --template-file main.bicep `
  --parameters parameters.dev.json
```

### What-If Validation with Azure CLI

Before deploying, validate your changes without actually creating resources:

```powershell
az deployment group what-if `
  --resource-group rg-myapp-dev `
  --template-file main.bicep `
  --parameters parameters.dev.json
```

### Example: VNet Template Deployment

```powershell
# Navigate to the VNet template folder
cd templates\vnet-windows

# Deploy with custom parameters
az deployment group create `
  --resource-group rg-myapp-prod `
  --template-file main.bicep `
  --parameters functionAppRuntime=dotnet-isolated `
               functionAppRuntimeVersion=8.0 `
               appName=myapp-func-prod `
               location=eastus2 `
  --debug
```

### Tips for Azure CLI Deployment

- **Login first**: Run `az login` before deploying
- **Set subscription**: Use `az account set --subscription <subscription-id>` to select the correct subscription
- **Create resource group**: If it doesn't exist, create it with `az group create --name <rg-name> --location <location>`
- **Parameter overrides**: Command-line parameters override those in parameter files
- **Debug mode**: The `--debug` flag provides detailed HTTP request/response information useful for troubleshooting

## �📝 Customizing Templates

### Creating Parameter Files for Different Environments

Each template includes a `parameters.dev.json` file. Create additional files for other environments:

```powershell
# Copy and modify for production
Copy-Item .\templates\basic-windows\parameters.dev.json .\templates\basic-windows\parameters.prod.json
```

Edit the new file to adjust settings:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "westus2"
    },
    "functionAppRuntime": {
      "value": "dotnet-isolated"
    },
    "functionAppRuntimeVersion": {
      "value": "8.0"
    },
    "maximumInstanceCount": {
      "value": 200
    },
    "instanceMemoryMB": {
      "value": 4096
    }
  }
}
```

### Modifying Bicep Templates

Each template folder contains a `main.bicep` file. You can:

1. Add new parameters
2. Modify SKUs or tiers
3. Add additional Azure resources
4. Change networking configurations

See the individual template README files for specific guidance.

## 🏗️ Common Deployment Scenarios

### Scenario 1: Quick Dev Environment

```powershell
.\scripts\Deploy-FunctionApp.ps1 -TemplateName "basic-windows" -Environment "dev" -ResourceGroupName "rg-dev-sandbox"
```

### Scenario 2: Production with Network Isolation

```powershell
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "vnet-windows" `
    -Environment "prod" `
    -ResourceGroupName "rg-prod-funcapp" `
    -Location "eastus2" `
    -SubscriptionId "your-subscription-id"
```

### Scenario 3: Python Workload with Security

```powershell
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "vnet-linux" `
    -Environment "prod" `
    -ResourceGroupName "rg-python-secure"
```

## 🔐 Security Features

All templates include:

- ✅ **Managed Identity**: No storage keys in configuration
- ✅ **HTTPS Only**: Enforced at the function app level
- ✅ **TLS 1.2+**: Minimum TLS version configured
- ✅ **No Public Blob Access**: Storage accounts secured
- ✅ **Shared Key Disabled**: Storage authentication via managed identity only
- ✅ **Application Insights**: With AAD authentication

VNet templates additionally include:

- ✅ **Private Endpoints**: For all storage services
- ✅ **Network Isolation**: Public access disabled
- ✅ **Private DNS**: Automatic DNS resolution
- ✅ **VNet Integration**: Function app in dedicated subnet

## 📊 Monitoring

All deployments include:

- **Application Insights**: Telemetry, logs, and metrics
- **Log Analytics Workspace**: 30-day retention
- **Managed Identity for App Insights**: Secure authentication

Access Application Insights in the Azure Portal to:

- View live metrics
- Query logs with KQL
- Set up alerts
- Create dashboards

## 🛠️ Troubleshooting

### Deployment Fails with Authorization Error

Ensure you have the necessary permissions:

- `Contributor` or `Owner` role on the resource group
- `User Access Administrator` for role assignments

### Bicep Compilation Errors

Update Bicep CLI to the latest version:

```powershell
az bicep upgrade
```

### Storage Access Issues

Check that:

1. Managed identity is assigned to the function app
2. Role assignments completed successfully
3. For VNet deployments, private endpoints are connected

### VNet Template Doesn't Connect to Storage

After deployment:

1. Verify private endpoints are in "Approved" state
2. Check DNS resolution from within the VNet
3. Ensure subnet delegation is correct

## 🔄 Updating Existing Deployments

Run the deployment script again with the same parameters. Bicep will:

- Update resources that changed
- Leave unchanged resources as-is
- Add new resources if template was modified

```powershell
# Re-run to update
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "basic-windows" `
    -Environment "dev" `
    -ResourceGroupName "rg-myapp-dev"
```

## 📚 Additional Resources

- [Azure Functions Documentation](https://learn.microsoft.com/azure/azure-functions/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Function App Best Practices](https://learn.microsoft.com/azure/azure-functions/functions-best-practices)
- [VNet Integration](https://learn.microsoft.com/azure/azure-functions/functions-networking-options)
- [Managed Identity for Azure Resources](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

## 🤝 Contributing

When you have a working configuration:

1. Create a new folder under `templates/`
2. Add `main.bicep`, parameter files, and README.md
3. Test the deployment thoroughly
4. Document any special requirements

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## ✨ Features Roadmap

Potential future templates:

- Flex Consumption plan deployments
- Container Apps integration
- API Management integration
- Azure Service Bus triggers
- Multi-region deployments
- Cosmos DB integration

---

**Version:** 1.0.0  
**Last Updated:** January 2026
