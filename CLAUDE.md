# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Production-ready Azure Bicep IaC templates for deploying Azure Function Apps. Licensed under MIT (see `LICENSE`). Four template variants exist under `templates/`: `basic-windows`, `basic-linux`, `vnet-windows`, `vnet-linux`. Each is self-contained with its own `main.bicep`, parameter files, and README. There is also a root `main.bicep` that serves as the original reference template.

## Deployment Commands

Deploy via the PowerShell orchestrator script:
```powershell
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "basic-windows" `
    -Environment "dev" `
    -ResourceGroupName "rg-myapp-dev" `
    -Location "eastus"
```

Validate without deploying (WhatIf mode):
```powershell
.\scripts\Deploy-FunctionApp.ps1 `
    -TemplateName "basic-windows" `
    -Environment "dev" `
    -ResourceGroupName "rg-test" `
    -WhatIf
```

Direct Azure CLI deployment (alternative):
```powershell
az deployment group create `
    --resource-group rg-myapp-dev `
    --template-file templates/basic-windows/main.bicep `
    --parameters templates/basic-windows/parameters.dev.json
```

Validate Bicep syntax: `az bicep build --file templates/<variant>/main.bicep`

## Architecture

### Template Variants

| Template | OS | VNet | Default Runtime | Use Case |
|---|---|---|---|---|
| `basic-windows` | Windows | No | dotnet-isolated 8.0 | Dev/simple workloads |
| `basic-linux` | Linux | No | python 3.11 | Python/Node.js workloads |
| `vnet-windows` | Windows | Yes | dotnet-isolated 8.0 | Production with network isolation |
| `vnet-linux` | Linux | Yes | python 3.11 | Secure Python/Node.js production |

Each template deploys: Storage Account, App Service Plan (P0v3), Function App, Managed Identity, Log Analytics Workspace, Application Insights, and RBAC role assignments. VNet variants add: VNet with two subnets, private endpoints (blob/table/queue), and private DNS zones.

### Resource Naming Convention

All templates generate a `resourceToken` via `toLower(uniqueString(subscription().id, location, ...))` and use it as a suffix:
- `log-{token}`, `appi-{token}`, `st{token}`, `plan-{token}`, `uai-data-owner-{token}`
- VNet resources: `vnet-{token}`, `pe-blob-{token}`, etc.

### Security Pattern (all templates)

- **Managed Identity auth** — storage keys are never used. `allowSharedKeyAccess: false` on all storage accounts.
- Four RBAC role assignments on storage: Blob Data Owner, Blob Data Contributor, Queue Data Contributor, Table Data Contributor.
- Monitoring Metrics Publisher role on App Insights.
- Role assignment names are deterministic via `guid()`.

### Windows vs Linux Differences

- Windows: `kind: 'functionapp'`, `reserved: false`, no `linuxFxVersion`
- Linux: `kind: 'functionapp,linux'`, `reserved: true`, sets `linuxFxVersion: '${upper(runtime)}|${version}'`

### VNet Pattern (vnet-* templates)

Two subnets: `snet-function` (delegated to `Microsoft.Web/serverFarms`) and `snet-privateendpoint`. Three private endpoints (blob, table, queue) with corresponding private DNS zones. Storage network ACLs default to `Deny`. Function app routes all traffic through VNet (`vnetRouteAllEnabled: true`).

### Parameter Files

Located at `templates/<variant>/parameters.<env>.json`. The deploy script resolves them dynamically as `parameters.${Environment}.json`. Create `parameters.prod.json`, `parameters.test.json` etc. for additional environments.

## Conventions When Editing Templates

- Templates are self-contained — no Bicep modules or linked templates. Each `main.bicep` defines all resources inline.
- Parameters are grouped at the top with `@allowed`, `@minValue`/`@maxValue` decorators for validation.
- Variables section holds Azure role definition IDs and environment-specific suffixes.
- Resource sections are separated by comment blocks (`//**//` pattern).
- API versions vary across templates; `basic-windows` uses the latest (`2025-02-01` for Log Analytics, `2025-06-01` for Storage). When updating a template, prefer matching the API versions used in `basic-windows` as the reference.
- When adding a new template variant, create a folder under `templates/` with `main.bicep`, `parameters.dev.json`, and `README.md`.
