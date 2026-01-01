# Basic Windows Function App Template

This template deploys a basic Azure Function App on Windows with the following features:

## Resources Deployed

- **Function App**: Windows-based Azure Function App
- **App Service Plan**: Premium v3 (P0v3) plan
- **Storage Account**: Standard LRS storage with managed identity authentication
- **Application Insights**: For monitoring and telemetry
- **Log Analytics Workspace**: Backend for Application Insights
- **User Assigned Managed Identity**: For secure access to storage and App Insights

## Key Features

- ✅ Managed Identity authentication (no storage keys required)
- ✅ HTTPS only
- ✅ TLS 1.2 minimum
- ✅ Always On enabled
- ✅ Shared key access disabled on storage account

## Parameters

| Parameter                 | Description                        | Default                 |
| ------------------------- | ---------------------------------- | ----------------------- |
| location                  | Azure region                       | Resource group location |
| functionAppRuntime        | Runtime (.NET, Python, Node, etc.) | `dotnet-isolated`       |
| functionAppRuntimeVersion | Runtime version                    | `8.0`                   |
| maximumInstanceCount      | Max scale-out instances            | `100`                   |
| instanceMemoryMB          | Memory per instance                | `2048`                  |
| resourceToken             | Unique token for naming            | Auto-generated          |
| appName                   | Function app name                  | `func-{resourceToken}`  |

## Deployment

Use the PowerShell deployment script from the project root:

```powershell
.\scripts\Deploy-FunctionApp.ps1 -TemplateName "basic-windows" -Environment "dev" -ResourceGroupName "rg-myapp-dev"
```

## Runtime Support

Supported runtimes:

- .NET Isolated (8.0, 9.0)
- Python (3.10, 3.11)
- Node.js (17, 20)
- Java (11, 17)
- PowerShell (7.4)
