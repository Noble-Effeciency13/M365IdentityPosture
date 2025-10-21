# M365IdentityPosture Module

A comprehensive PowerShell module for security posture assessment and identity governance reporting across Microsoft 365, Azure, and hybrid environments.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)
![Version](https://img.shields.io/badge/Version-1.0.0-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/M365IdentityPosture?label=PSGallery%20Downloads&color=orange)
![PSGallery Version](https://img.shields.io/powershellgallery/v/M365IdentityPosture?label=PSGallery%20Version)

## 🎯 Overview

M365IdentityPosture is a comprehensive PowerShell module for security posture assessment and identity governance reporting across Microsoft 365, Azure AD/Entra ID, and hybrid environments. While the initial release focuses on Authentication Context inventory, the framework is designed to expand into comprehensive identity and security analytics.

### Current Capabilities (v1.0)
- **Authentication Context Inventory**: Complete analysis of authentication context usage across Microsoft 365 services
- **Cross-Service Correlation**: Maps authentication requirements across Purview, Conditional Access, PIM, SharePoint, and Teams
- **Security Gap Identification**: Identifies unused or misconfigured authentication contexts

### 🚀 Roadmap
- **Access Package Analytics**: Entitlement management and access review reporting
- **Role Assignment Auditing**: Comprehensive RBAC and privileged role analysis
- **Conditional Access Gap Analysis**: Policy coverage and security gap identification
- **Identity Protection Insights**: Risk-based access and identity security metrics
- **Governance Workflows**: Automated compliance and attestation reporting

## ✨ Key Features

### 📊 Comprehensive Service Coverage

- **📋 Purview Sensitivity Labels**
  - Discovers labels with embedded Authentication Context requirements
  - Maps label inheritance to groups and sites
  - Tracks label application across services
  
- **🔒 Conditional Access Policies**
  - Maps policies referencing Authentication Contexts
  - Identifies target users, groups, and applications
  - Analyzes policy effectiveness and gaps
  
- **👥 Privileged Identity Management (PIM)**
  - Directory role management policies
  - Group-based PIM policies with role assignments
  - Azure resource PIM policies (optional)
  - Just-in-time access configuration analysis
  
- **📁 SharePoint Online**
  - Direct Authentication Context assignments on sites
  - Inherited context through sensitivity labels
  - Site-level security posture assessment
  
- **👥 Microsoft 365 Groups & Teams**
  - Label inheritance tracking
  - Context enforcement analysis
  - Team and channel security configuration
  
- **🛡️ Protected Actions**
  - RBAC resource actions with context requirements
  - Cross-service authentication context mapping
  - Critical operation protection analysis

### 📈 Reporting Capabilities

- **Interactive HTML Reports** with rich formatting and data visualization
- **Comprehensive Metrics Dashboard** with KPIs and trends
- **Cross-Reference Analysis** between all services
- **Detailed Inventory Tables** with filtering and sorting
- **Export-Ready Data** in multiple formats for further analysis
- **Executive Summaries** for leadership reporting

## 💡 Use Cases

### Security Auditing
- Quarterly security posture assessments
- Compliance reporting for authentication standards
- Pre/post implementation validation
- Zero Trust maturity assessment

### Identity Governance
- Access review preparation
- Privileged role inventory
- Entitlement management optimization
- Lifecycle management analysis

### Migration Planning
- Zero Trust readiness assessment
- Authentication method modernization
- Legacy access identification
- Cloud security baseline establishment

### Compliance & Risk Management
- Regulatory compliance validation
- Risk assessment documentation
- Security control effectiveness measurement
- Audit evidence collection

## 📋 Prerequisites

### System Requirements

- **PowerShell**: Version 7.0 or higher (PowerShell Core)
- **Operating System**: Windows 10/11, Windows Server 2019+, macOS, Linux

### Module Dependencies

This module **dynamically loads and unloads** its dependencies as needed for each reporting phase. You do **not** need to import all modules up front. The following modules are required and will be loaded automatically when needed:

```powershell
# Core modules (always required for at least one phase)
Microsoft.Graph.Authentication
Microsoft.Graph.Groups
ExchangeOnlineManagement
Microsoft.Online.SharePoint.PowerShell

# Azure modules (only if Azure PIM reporting is enabled)
Az.Accounts
Az.Resources
```

**Note:** The module handles loading and unloading as needed. If a required module is missing, you will be prompted to install it, or the report will skip that phase.

### Required Permissions

Minimum permissions needed for full functionality:

#### Microsoft Graph API
- `Directory.Read.All`
- `Group.Read.All`
- `Policy.Read.All`
- `Policy.Read.ConditionalAccess`
- `AuthenticationContext.Read.All`
- `RoleManagement.Read.Directory`
- `PrivilegedAccess.Read.AzureADGroup`
- `InformationProtectionPolicy.Read.All`

#### Service-Specific Roles
- **Exchange Online**: View-Only Organization Management
- **SharePoint Online**: SharePoint Administrator or Global Reader
- **Azure**: Reader role on subscriptions (for Azure PIM enumeration)

## 📦 Installation

### Option 1: From PowerShell Gallery (Recommended)

```powershell
# Install from PSGallery
Install-Module -Name M365IdentityPosture -Scope CurrentUser

# Or install for all users (requires admin)
Install-Module -Name M365IdentityPosture -Scope AllUsers
```

### Option 2: Manual Installation

1. **Clone or download this repository**

```powershell
git clone https://github.com/Noble-Effeciency13/M365IdentityPosture.git
```

2. **Copy to PowerShell modules directory**

```powershell
# Check available module paths
$env:PSModulePath -split ';'

# Copy to user module path (recommended)
$modulePath = "$HOME\Documents\PowerShell\Modules\M365IdentityPosture"
Copy-Item -Path ".\M365IdentityPosture\*" -Destination $modulePath -Recurse -Force
```

3. **Import the module**

```powershell
Import-Module M365IdentityPosture
```

## 🚀 Usage

### Quick Start

```powershell
# Import the module
Import-Module M365IdentityPosture

# Run the authentication context inventory report
Invoke-AuthContextInventoryReport -TenantName "contoso"
```

### Detailed Examples

#### Standard Full Inventory

```powershell
# Full inventory with all services
Invoke-AuthContextInventoryReport ´
    -TenantName "contoso" ´
    -OutputPath "C:\Reports\AuthContext" ´
    -UserPrincipalName "admin@contoso.com"
```

#### Quiet Mode with Custom Output

```powershell
# Run quietly with custom HTML path
Invoke-AuthContextInventoryReport ´
    -TenantName "contoso" ´
    -HtmlReportPath "D:\Security\AuthContext_$(Get-Date -Format 'yyyyMMdd').html" ´
    -Quiet ```
    -NoAutoOpen
```

#### Exclude Azure PIM Enumeration

```powershell
# Skip Azure resource PIM enumeration (faster)
Invoke-AuthContextInventoryReport ´
    -TenantName "contoso" ´
    -ExcludeAzure
```

#### Target Specific Azure Subscriptions

```powershell
# Process only specific Azure subscriptions
$subscriptions = @(
    'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
)

Invoke-AuthContextInventoryReport ´
    -TenantName "contoso" ´
    -AzureSubscriptionIds $subscriptions
```

### Parameters Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **-TenantName** | String | SharePoint tenant name (e.g., 'contoso' for contoso.sharepoint.com) | Auto-detected from current context |
| **-OutputPath** | String | Directory path for report output files | `C:\Reports\M365AuthContext` |
| **-UserPrincipalName** | String | UPN for authentication hints | Current user's UPN |
| **-Quiet** | Switch | Suppresses non-essential console output | `$false` |
| **-NoProgress** | Switch | Suppresses progress bars during execution | `$false` |
| **-HtmlReportPath** | String | Custom path for HTML report output | Auto-generated with timestamp |
| **-NoAutoOpen** | Switch | Prevents automatic opening of HTML report | `$false` |
| **-ExcludeAzure** | Switch | Skips Azure resource PIM enumeration | `$false` |
| **-AzureSubscriptionIds** | String[] | Specific Azure subscription IDs to process | All accessible subscriptions |

## 🏗️ Module Architecture

    M365IdentityPosture/
    ├── M365IdentityPosture.psd1       # Module manifest
    ├── M365IdentityPosture.psm1       # Root module with banner
    ├── Public/                         # Exported functions
    │   ├── Invoke-AuthContextInventoryReport.ps1
    │   ├── (Future) Invoke-AccessPackageReport.ps1
    │   ├── (Future) Invoke-RoleAssignmentAudit.ps1
    │   └── (Future) Invoke-CAGapAnalysis.ps1
    ├── Private/                        # Internal functions (organized by domain)
    │   ├── AuthContext/               # Authentication context specific
    │   ├── Authentication/            # Service connections
    │   ├── DataCollection/            # Cross-service data retrieval
    │   ├── DataProcessing/            # Data transformation
    │   ├── Orchestration/             # Workflow coordination
    │   ├── ReportGeneration/          # HTML/Export generation
    │   └── Utilities/                 # Shared helpers
    └── Tests/                         # Pester tests and validation


## 📊 Report Output

### HTML Report Structure

The generated HTML report includes a flexible layout system with runtime theme switching:

#### Executive Summary Dashboard
- Total Authentication Contexts defined
- Active vs. Inactive contexts
- Service coverage metrics
- Security posture indicators
- Risk assessment scores

#### Detailed Inventory Sections

1. **Authentication Contexts**
   - All defined contexts with status and configuration
   - Usage statistics across services
   - Orphaned or unused contexts
   
2. **Sensitivity Labels**
   - Labels enforcing authentication contexts
   - Label hierarchy and inheritance
   - Application coverage metrics
   
3. **SharePoint Sites**
   - Direct context assignments
   - Inherited contexts via labels
   - Site security posture scoring
   
4. **Microsoft 365 Groups/Teams**
   - Groups with context-enforcing labels
   - Teams channel inheritance
   - Guest access implications
   
5. **Conditional Access Policies**
   - Policies referencing authentication contexts
   - Target users, groups, and applications
   - Policy effectiveness analysis
   
6. **Protected Actions**
   - RBAC actions requiring contexts
   - Service-specific protections
   - Critical operation coverage
   
7. **PIM Policies**
   - Directory role policies with contexts
   - Group-based PIM configurations
   - Azure resource PIM policies
   - Just-in-time access patterns

### Themes & Runtime Toggle

Two base themes with instant runtime switching:
- **Classic** (light theme) - Default professional appearance
- **Dark** (dark theme) - Reduced eye strain for extended viewing

Reports include a theme toggle button for instant switching without regeneration.

## 🚀 Roadmap & Future Reports

The M365IdentityPosture module is actively expanding to include:

### Access Governance
- **Access Package Reports**
  - Access package utilization metrics
  - Assignment lifecycle analytics
  - Approval workflow analysis
  - Expiration and recertification tracking

### Privileged Access
- **Role Assignment Reports**
  - Privileged role usage patterns
  - Role activation history
  - Standing vs eligible assignments
  - Separation of duties analysis
  - Role mining recommendations

### Policy Analytics
- **Conditional Access Gap Analysis**
  - Uncovered users and applications
  - Policy overlap and conflicts
  - MFA and device compliance gaps
  - Sign-in risk coverage
  - Location-based access patterns

### Identity Protection
- **Identity Security Dashboard**
  - Security defaults assessment
  - Identity Protection policy effectiveness
  - Risky user and sign-in analytics
  - Password health metrics
  - Authentication method analysis

### Future Considerations
- Hybrid identity synchronization health
- Cross-cloud security posture (AWS/GCP integration)
- Automated remediation recommendations
- Integration with Microsoft Secure Score
- Custom compliance framework mapping
- Maester integration

## 🔍 Troubleshooting

### Common Issues and Solutions

#### PowerShell Version Issues

```powershell
# Check your PowerShell version
$PSVersionTable.PSVersion

# If version < 7.0, install PowerShell 7+
# Windows
winget install Microsoft.PowerShell

# macOS
brew install --cask powershell

# Linux
# See: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
```

#### Module Import Failures

```powershell
# Verify module is in correct path
Get-Module -ListAvailable M365IdentityPosture

# Check for missing dependencies
Test-ModuleManifest -Path ".\M365IdentityPosture\M365IdentityPosture.psd1"

# Force reload if cached
Remove-Module M365IdentityPosture -Force -ErrorAction SilentlyContinue
Import-Module M365IdentityPosture -Force
```

#### Authentication Issues

```powershell
# Clear existing Graph context
Disconnect-MgGraph

# Re-authenticate with required scopes
Connect-MgGraph -Scopes @(
    "Directory.Read.All",
    "Policy.Read.All",
    "Group.Read.All",
    "Policy.Read.ConditionalAccess",
    "AuthenticationContext.Read.All",
    "RoleManagement.Read.Directory",
    "PrivilegedAccess.Read.AzureADGroup",
    "InformationProtectionPolicy.Read.All"
)

# Verify connected account
Get-MgContext
```

### Logging and Debugging

Detailed logs are automatically generated:

```powershell
# Default log location
# Windows: %TEMP%\M365IdentityPosture_YYYYMMDD_HHMMSS.log
# Linux/macOS: /tmp/M365IdentityPosture_YYYYMMDD_HHMMSS.log

# View current session log
Get-Content "$env:TEMP\M365IdentityPosture_*.log" | Select-Object -Last 100

# Enable verbose output for debugging
Invoke-AuthContextInventoryReport -TenantName "contoso" -Verbose

# Enable debug output for maximum detail
$DebugPreference = 'Continue'
Invoke-AuthContextInventoryReport -TenantName "contoso"
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Contributing New Reports

When adding a new security or identity report:

1. **Follow the established pattern**: 
   - Public function: `Invoke-<ReportName```Report`
   - Private orchestration in appropriate folders
   - Consistent parameter naming

2. **Maintain module philosophy**:
   - Read-only operations only
   - Comprehensive error handling
   - Progress reporting for long operations
   - HTML output with metrics dashboard

3. **Documentation requirements**:
   - Complete comment-based help
   - README section for new report
   - Sample output screenshots
   - Required permissions documentation

### Development Process

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/AmazingFeature`)
3. **Commit your changes** (`git commit -m 'Add some AmazingFeature'`)
4. **Push to the branch** (`git push origin feature/AmazingFeature`)
5. **Open a Pull Request**

### Development Guidelines

- Follow PowerShell best practices and style guidelines
- Add Pester tests for new functions
- Update documentation for new features
- Ensure backward compatibility
- Test with PowerShell 7+ on multiple platforms
- Use tab characters for indentation (not spaces)
- Include comprehensive comment-based help

## 🌟 Community

- **⭐ Star this repo** if you find it useful
- **👀 Watch** for updates on new reports
- **🍴 Fork** to customize for your organization
- **💬 Share** your use cases and success stories
- **🐛 Report issues** to help improve the module
- **💡 Suggest features** for future development

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Sebastian Flæng Markdanner**
- 🌐 Website: [https://chanceofsecurity.com](https://chanceofsecurity.com)
- 🐙 GitHub: [@Noble-Effeciency13](https://github.com/Noble-Effeciency13)
- 💼 LinkedIn: [Sebastian Markdanner](https://linkedin.com/in/sebastianmarkdanner)

## 🙏 Acknowledgments

- Microsoft Graph PowerShell SDK team
- Exchange Online Management module team
- SharePoint PnP Community
- Azure PowerShell team
- The PowerShell community
- All contributors and users providing feedback

## 📚 Resources

- [Microsoft Graph API Documentation](https://docs.microsoft.com/graph/)
- [Authentication Context Overview](https://docs.microsoft.com/azure/active-directory/conditional-access/concept-authentication-context)
- [Conditional Access Documentation](https://docs.microsoft.com/azure/active-directory/conditional-access/)
- [PIM Documentation](https://docs.microsoft.com/azure/active-directory/privileged-identity-management/)
- [Sensitivity Labels Documentation](https://docs.microsoft.com/microsoft-365/compliance/sensitivity-labels)
- [Zero Trust Guidance](https://www.microsoft.com/security/business/zero-trust)

## 🔄 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes, updates, and version information.

### Latest Version: 1.0.0 (2025-10-21)
- Initial release with Authentication Context inventory capabilities
- Full Microsoft 365 service coverage
- Rich HTML reporting with theme support
- See [full changelog](CHANGELOG.md#100---2025-10-21) for complete details

---

## 📮 Support

For bugs, feature requests, or questions:
- 🐛 Open an [issue](https://github.com/Noble-Effeciency13/M365IdentityPosture/issues)
- 💬 Check [discussions](https://github.com/Noble-Effeciency13/M365IdentityPosture/discussions) for Q&A
- 🌐 Follow updates on [Chance of Security](https://chanceofsecurity.com)

---

**⚠️ Important Note**: This module performs read-only operations and does not modify any configurations in your tenant. Always review the generated reports and verify findings in your environment. Use the insights provided to enhance your security posture through informed decision-making.

**🔒 Security**: For security concerns or vulnerability reports, please email security@chanceofsecurity.com rather than using public issues.
