<#
.SYNOPSIS
    Deploys Azure Function App infrastructure using Bicep templates.

.DESCRIPTION
    This script deploys Azure Function Apps and supporting infrastructure using
    pre-configured Bicep templates. It supports multiple deployment templates
    for different scenarios (basic, VNet-enabled, Windows, Linux).

.PARAMETER TemplateName
    The name of the template to deploy. Must match a folder name under .\templates\.
    Options: basic-windows, basic-linux, vnet-windows, vnet-linux

.PARAMETER Environment
    The environment name (dev, test, prod). This affects which parameter file is used.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to deploy to.

.PARAMETER Location
    Azure region for the resource group. Default: eastus

.PARAMETER SubscriptionId
    Azure subscription ID. If not provided, uses the current subscription.

.PARAMETER AppName
    Optional custom name for the function app. If not provided, auto-generated from resourceToken.

.PARAMETER ResourceToken
    Optional custom resource token for naming. If not provided, auto-generated.

.PARAMETER WhatIf
    Performs a validation deployment without actually deploying resources.

.EXAMPLE
    .\Deploy-FunctionApp.ps1 -TemplateName "basic-windows" -Environment "dev" -ResourceGroupName "rg-myapp-dev"

.EXAMPLE
    .\Deploy-FunctionApp.ps1 -TemplateName "vnet-linux" -Environment "prod" -ResourceGroupName "rg-myapp-prod" -Location "westus2"

.EXAMPLE
    .\Deploy-FunctionApp.ps1 -TemplateName "basic-windows" -Environment "dev" -ResourceGroupName "rg-test" -WhatIf

.NOTES
    Author: Azure Function App Templates
    Requires: Azure PowerShell Az module
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('basic-windows', 'basic-linux', 'vnet-windows', 'vnet-linux')]
    [string]$TemplateName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'eastus',

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$AppName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceToken,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Functions

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Blue
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Warning "Not logged in to Azure. Please sign in..."
            Connect-AzAccount
            $context = Get-AzContext
        }
        Write-Success "Connected to Azure as $($context.Account.Id)"
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        return $false
    }
}

function Set-AzureSubscription {
    param([string]$SubId)
    
    if ($SubId) {
        try {
            Set-AzContext -SubscriptionId $SubId | Out-Null
            Write-Success "Switched to subscription: $SubId"
        }
        catch {
            Write-Error "Failed to set subscription context: $_"
        }
    }
    
    $currentContext = Get-AzContext
    Write-Info "Using subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))"
}

function New-ResourceGroupIfNotExists {
    param(
        [string]$Name,
        [string]$Loc
    )
    
    $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Info "Creating resource group '$Name' in '$Loc'..."
        New-AzResourceGroup -Name $Name -Location $Loc | Out-Null
        Write-Success "Resource group created successfully"
    }
    else {
        Write-Info "Resource group '$Name' already exists in '$($rg.Location)'"
    }
}

function Get-TemplateFiles {
    param([string]$Template)
    
    $scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $scriptDir) {
        $scriptDir = Get-Location
    }
    
    $templateDir = Join-Path (Split-Path -Parent $scriptDir) "templates\$Template"
    $bicepFile = Join-Path $templateDir "main.bicep"
    $paramFile = Join-Path $templateDir "parameters.$Environment.json"
    
    if (-not (Test-Path $bicepFile)) {
        throw "Bicep template not found: $bicepFile"
    }
    
    if (-not (Test-Path $paramFile)) {
        Write-Warning "Parameter file not found: $paramFile"
        Write-Info "Proceeding without parameter file. Template defaults will be used."
        $paramFile = $null
    }
    
    return @{
        BicepFile     = $bicepFile
        ParameterFile = $paramFile
    }
}

function Start-BicepDeployment {
    param(
        [string]$RgName,
        [string]$BicepPath,
        [string]$ParamPath,
        [hashtable]$AdditionalParams,
        [bool]$IsWhatIf
    )
    
    $deploymentName = "funcapp-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    # Build deployment parameters
    $deployParams = @{
        Name              = $deploymentName
        ResourceGroupName = $RgName
        TemplateFile      = $BicepPath
        Verbose           = $true
    }
    
    if ($ParamPath) {
        $deployParams['TemplateParameterFile'] = $ParamPath
    }
    
    # Add override parameters
    if ($AdditionalParams.Count -gt 0) {
        foreach ($key in $AdditionalParams.Keys) {
            $deployParams[$key] = $AdditionalParams[$key]
        }
    }
    
    try {
        if ($IsWhatIf) {
            Write-Header "VALIDATION MODE - No resources will be deployed"
            $result = Test-AzResourceGroupDeployment @deployParams
            
            if ($result) {
                Write-Warning "Validation found issues:"
                $result | Format-List
                return $false
            }
            else {
                Write-Success "Validation passed! Template is valid."
                return $true
            }
        }
        else {
            Write-Header "Starting Deployment"
            Write-Info "Deployment name: $deploymentName"
            
            $deployment = New-AzResourceGroupDeployment @deployParams
            
            if ($deployment.ProvisioningState -eq 'Succeeded') {
                Write-Success "Deployment completed successfully!"
                
                # Display outputs if any
                if ($deployment.Outputs.Count -gt 0) {
                    Write-Header "Deployment Outputs"
                    $deployment.Outputs | Format-Table -AutoSize
                }
                
                return $true
            }
            else {
                Write-Warning "Deployment state: $($deployment.ProvisioningState)"
                return $false
            }
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        Write-Error $_.Exception.Message
        if ($_.Exception.InnerException) {
            Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
        }
        return $false
    }
}

#endregion

#region Main Script

Write-Header "Azure Function App Deployment Script"

# Display deployment configuration
Write-Info "Configuration:"
Write-Host "  Template:       $TemplateName" -ForegroundColor White
Write-Host "  Environment:    $Environment" -ForegroundColor White
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Location:       $Location" -ForegroundColor White
if ($AppName) { Write-Host "  App Name:       $AppName" -ForegroundColor White }
if ($ResourceToken) { Write-Host "  Resource Token: $ResourceToken" -ForegroundColor White }
if ($WhatIf) { Write-Host "  Mode:           VALIDATION ONLY" -ForegroundColor Yellow }

# Check Azure connection
if (-not (Test-AzureConnection)) {
    exit 1
}

# Set subscription if specified
Set-AzureSubscription -SubId $SubscriptionId

# Create resource group if needed
New-ResourceGroupIfNotExists -Name $ResourceGroupName -Loc $Location

# Get template files
Write-Header "Loading Template Files"
$files = Get-TemplateFiles -Template $TemplateName
Write-Info "Bicep template: $($files.BicepFile)"
if ($files.ParameterFile) {
    Write-Info "Parameters file: $($files.ParameterFile)"
}

# Prepare override parameters
$overrideParams = @{}
if ($AppName) {
    $overrideParams['appName'] = $AppName
}
if ($ResourceToken) {
    $overrideParams['resourceToken'] = $ResourceToken
}
if ($Location) {
    $overrideParams['location'] = $Location
}

# Start deployment
$success = Start-BicepDeployment `
    -RgName $ResourceGroupName `
    -BicepPath $files.BicepFile `
    -ParamPath $files.ParameterFile `
    -AdditionalParams $overrideParams `
    -IsWhatIf $WhatIf.IsPresent

# Summary
Write-Header "Deployment Summary"
if ($success) {
    Write-Success "Deployment completed successfully!"
    
    if (-not $WhatIf) {
        Write-Info "`nNext steps:"
        Write-Host "  1. Review deployed resources in Azure Portal" -ForegroundColor White
        Write-Host "  2. Deploy your function app code" -ForegroundColor White
        Write-Host "  3. Configure any additional app settings" -ForegroundColor White
        Write-Host "  4. Test your function app" -ForegroundColor White
    }
}
else {
    Write-Error "Deployment failed or validation errors occurred"
    exit 1
}

#endregion
