# M365IdentityPosture Module

A comprehensive PowerShell module for security posture assessment and identity governance reporting across Microsoft 365, Azure, and hybrid environments.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)
![PSGallery Version](https://img.shields.io/powershellgallery/v/M365IdentityPosture?label=PSGallery%20Version)
![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/M365IdentityPosture?label=PSGallery%20Downloads&color=orange)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 📑 Table of Contents

- [Overview](#-overview)
- [What's Included](#-whats-included)
- [Installation](#-installation)
- [Prerequisites](#-prerequisites)
- [Reports](#-reports)
  - [Authentication Context Inventory](#-authentication-context-inventory)
  - [Access Package Documentor](#-access-package-documentor)
- [Common Features](#-common-features)
- [Use Cases](#-use-cases)
- [Module Architecture](#️-module-architecture)
- [Troubleshooting](#-troubleshooting)
- [Roadmap](#-roadmap--future-reports)
- [Contributing](#-contributing)
- [Author & Contributors](#-author---contributors)
- [Changelog](#-changelog)
- [Support](#-support)

## 🎯 Overview

M365IdentityPosture is an extensible PowerShell framework for security posture assessment and identity governance reporting across Microsoft 365, Azure AD/Entra ID, and hybrid environments. Built with a modular architecture, the framework provides specialized reports for different identity and access management scenarios, with each report generating interactive HTML output featuring runtime theme switching and comprehensive data visualization.

## 🎁 What's Included

The module currently includes two comprehensive reports:

- **🔐 Authentication Context Inventory**: Maps authentication context requirements and enforcement across Microsoft 365 services including Purview, Conditional Access, PIM, SharePoint, and Teams. Identifies security gaps and configuration issues.

- **📦 Access Package Documentor**: Interactive graph-based visualization and documentation of Entitlement Management. Features Cytoscape.js graph visualization with filtering, search, zoom/pan controls, and multi-format export (PNG, Markdown, JSON). *Co-developed with Christian Frohn*.

Both reports generate interactive HTML with runtime theme switching (Classic/Light and Dark) and are designed for security auditors, compliance teams, and identity governance professionals.

## 📋 Prerequisites

### System Requirements

- **PowerShell**: Version 7.0 or higher (PowerShell Core)
- **Operating System**: Windows 10/11, Windows Server 2019+, macOS, Linux

### Module Dependencies

This module **dynamically loads and unloads** its dependencies as needed for each reporting phase. You do **not** need to import all modules up front. The following modules are required and will be loaded automatically when needed:

```powershell
# Authentication Context Inventory dependencies
Microsoft.Graph.Authentication
Microsoft.Graph.Groups
ExchangeOnlineManagement
Microsoft.Online.SharePoint.PowerShell

# Access Package Documentor dependencies
Microsoft.Graph.Authentication
Microsoft.Graph.Identity.Governance

# Azure modules (only if Azure PIM reporting is enabled in AuthContext)
Az.Accounts
Az.Resources
```

**Note:** The module handles loading and unloading as needed. If a required module is missing, you will be prompted to install it, or the report will skip that phase.

### Required Permissions

Minimum permissions needed vary by report:

#### Authentication Context Inventory Report
**Microsoft Graph API:**
- `Directory.Read.All`
- `Group.Read.All`
- `Policy.Read.All`
- `Policy.Read.ConditionalAccess`
- `AuthenticationContext.Read.All`
- `RoleManagement.Read.Directory`
- `PrivilegedAccess.Read.AzureADGroup`
- `InformationProtectionPolicy.Read.All`

**Service-Specific Roles:**
- **Exchange Online**: View-Only Organization Management
- **SharePoint Online**: SharePoint Administrator or Global Reader
- **Azure**: Reader role on subscriptions (for Azure PIM enumeration)

#### Access Package Documentor Report
**Microsoft Graph API:**
- `EntitlementManagement.Read.All`
- `Directory.Read.All` (for resolving directory objects)

## � Installation

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

## 📊 Reports

### 🔐 Authentication Context Inventory

**Purpose**: Comprehensive discovery and analysis of authentication context enforcement across Microsoft 365 services, providing visibility into where and how authentication requirements are applied throughout your tenant.

**When to Use**:
- Security posture assessments and Zero Trust maturity evaluation
- Compliance audits requiring authentication requirements documentation
- Gap analysis of authentication context enforcement
- Pre/post implementation validation of authentication policies

**Quick Start**:

```powershell
# Import the module
Import-Module M365IdentityPosture

# Basic usage - discovers all authentication contexts across services
Invoke-AuthContextInventoryReport

# Exclude Azure PIM enumeration for faster execution
Invoke-AuthContextInventoryReport -ExcludeAzure

# Custom output path with quiet mode
Invoke-AuthContextInventoryReport `
    -TenantName "contoso" `
    -OutputPath "C:\Reports\AuthContext" `
    -Quiet `
    -NoAutoOpen
```

**Key Capabilities**:
- **Purview Sensitivity Labels**: Discovers labels with embedded authentication context requirements and tracks label inheritance
- **Conditional Access Policies**: Maps policies referencing authentication contexts with target users, groups, and applications
- **Privileged Identity Management (PIM)**: Analyzes directory role policies, group-based PIM, and Azure resource PIM policies (optional)
- **SharePoint Online**: Identifies direct authentication context assignments and inherited contexts through labels
- **Microsoft 365 Groups & Teams**: Tracks label inheritance and context enforcement across teams and channels
- **Protected Actions**: Maps RBAC resource actions requiring authentication contexts
- **Cross-Service Correlation**: Identifies relationships and dependencies between services
- **Gap Identification**: Highlights unused or misconfigured authentication contexts

**Parameters**: For complete parameter documentation and advanced examples, run:
```powershell
Get-Help Invoke-AuthContextInventoryReport -Full
```

---

### 📦 Access Package Documentor

**Purpose**: Interactive graph-based visualization and comprehensive documentation of Entitlement Management configurations, providing clear visibility into access package structures, policies, workflows, and resource assignments.

**When to Use**:
- Access review preparation and delegation audits
- Onboarding/offboarding process documentation
- Entitlement management optimization and cleanup
- Compliance reporting for access governance

**Quick Start**:

```powershell
# Import the module
Import-Module M365IdentityPosture

# Basic usage - documents all access packages and catalogs
Invoke-AccessPackageDocumentor -OutputPath "C:\Reports\AccessPackages"

# Use dark theme
Invoke-AccessPackageDocumentor `
    -OutputPath "C:\Reports" `
    -Theme Dark

# Quiet mode without auto-opening the report
Invoke-AccessPackageDocumentor `
    -OutputPath "C:\Reports" `
    -Quiet `
    -NoAutoOpen
```

**Key Capabilities**:
- **Access Package Structure**: Complete inventory of access packages, catalogs, and assignment policies
- **Resource Assignments**: Maps resource role scopes including groups applications, SharePoint sites, and Teams
- **Approval Workflows**: Documents multi-stage approval processes with approvers and escalation settings
- **Policy Configurations**: Captures expiration settings, access reviews, requestor questions, and custom extensions
- **Verified ID Integration**: Shows Verified ID requirements in policies when configured
- **Interactive Cytoscape.js Graph**: 
  - Zoom, pan, and drag-to-explore visualizations
  - Filter by catalog, access package, policy, or resource type
  - Full-text search across all node labels
  - Click nodes to view detailed information in side panel
  - Layout optimization for different graph sizes
- **Multi-Format Export**:
  - **PNG/JPEG**: High-resolution graph screenshots
  - **Markdown**: Hierarchical documentation with all details
  - **JSON**: Structured data for external processing or integration

**Parameters**: For complete parameter documentation and advanced examples, run:
```powershell
Get-Help Invoke-AccessPackageDocumentor -Full
```

*This report was co-developed with [Christian Frohn](https://github.com/ChrFrohn).*

---

## ✨ Common Features

All reports in the M365IdentityPosture module share these capabilities:

### Runtime Theme Switching
Both reports generate HTML with two built-in themes:
- **Classic (Light)**: Default professional appearance with high contrast
- **Dark**: Reduced eye strain for extended viewing sessions

Reports include a theme toggle button for instant switching without regenerating the report.

### Dynamic Module Loading
The module automatically loads required PowerShell modules on-demand for each phase and unloads them afterward to free memory. No need to pre-import dependencies.

### Comprehensive Logging
Detailed execution logs are automatically generated in your temp directory with timestamps:
- **Windows**: `%TEMP%\M365IdentityPosture_YYYYMMDD_HHMMSS.log`
- **Linux/macOS**: `/tmp/M365IdentityPosture_YYYYMMDD_HHMMSS.log`

### Read-Only Operations
All reports perform read-only operations with no tenant modifications, making them safe to run in production environments.

### Progress Reporting
Visual progress indicators and status messages keep you informed during long-running operations across multiple services.

## 💡 Use Cases

The M365IdentityPosture module addresses key identity and access management scenarios:

- **Security Posture Assessment**: Quarterly evaluations and Zero Trust maturity benchmarking
- **Compliance Auditing**: Authentication requirements documentation and regulatory validation
- **Access Governance**: Access review preparation and entitlement management optimization
- **Identity Lifecycle Management**: Onboarding/offboarding process documentation and validation
- **Gap Analysis**: Identify security gaps, misconfigurations, and unused resources
- **Migration Planning**: Zero Trust readiness assessment and authentication modernization
- **Audit Evidence**: Generate compliance documentation and security control effectiveness reports

Both reports complement each other: use **Authentication Context Inventory** for security policy enforcement analysis, and **Access Package Documentor** for access governance and delegation workflows.

## 🏗️ Module Architecture

    M365IdentityPosture/
    ├── M365IdentityPosture.psd1       # Module manifest
    ├── M365IdentityPosture.psm1       # Root module with banner
    ├── Public/                         # Exported functions
    │   ├── Invoke-AuthContextInventoryReport.ps1
    │   └── Invoke-AccessPackageDocumentor.ps1
    ├── Private/                        # Internal functions (organized by domain)
    │   ├── AuthContext/               # Authentication context specific
    │   ├── Authentication/            # Service connections
    │   ├── DataCollection/            # Cross-service data retrieval
    │   ├── DataProcessing/            # Data transformation
    │   ├── Orchestration/             # Workflow coordination
    │   ├── ReportGeneration/          # HTML/Export generation
    │   └── Utilities/                 # Shared helpers
    └── Tests/                         # Pester tests and validation


## 🔍 Troubleshooting

### Common Issues and Solutions

#### PowerShell Version Issues
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

## 🚀 Roadmap & Future Reports

The M365IdentityPosture module continues to expand with additional identity and access management reports:

### Planned Reports

- **Role Assignment Auditing**
  - Privileged role usage patterns and activation history
  - Standing vs eligible assignments analysis
  - Separation of duties validation
  - Role mining and optimization recommendations

- **Conditional Access Gap Analysis**
  - Uncovered users and applications identification
  - Policy overlap and conflict detection
  - MFA and device compliance gap analysis
  - Sign-in risk coverage evaluation
  - Location-based access pattern analysis

- **Identity Protection Dashboard**
  - Security defaults effectiveness assessment
  - Identity Protection policy analysis
  - Risky user and sign-in analytics
  - Password health metrics
  - Authentication method distribution

### Future Considerations

- Hybrid identity synchronization health monitoring
- Cross-cloud security posture (AWS/GCP integration)
- Automated remediation recommendations
- Microsoft Secure Score integration
- Custom compliance framework mapping
- Maester test framework integration

**Timeline**: Development priorities are determined by community feedback and organizational needs. Contributions are welcome! See the [Contributing](#-contributing) section for guidelines.

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

## 👤 Author & 🤝 Contributors

**Sebastian Flæng Markdanner** - *Module Author*
- 🌐 Website: [https://chanceofsecurity.com](https://chanceofsecurity.com)
- 🐙 GitHub: [@Noble-Effeciency13](https://github.com/Noble-Effeciency13)
- 💼 LinkedIn: [Sebastian Markdanner](https://www.linkedin.com/in/sebastian-markdanner/)

### Contributors

**Christian Frohn** - *Access Package Documentor Co-Author*
- Collaborative development of the Access Package Documentor feature
- 🌐 Website: [https://www.christianfrohn.dk/](https://www.christianfrohn.dk/)
- 🐙 GitHub: [@ChrFrohn](https://github.com/ChrFrohn)
- 💼 LinkedIn: [Christian Frohn](https://www.linkedin.com/in/frohn/)

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

### Latest Version: 1.1.0 (2026-03-12)
- **New Feature**: Access Package Documentor with interactive graph visualization
- Interactive Cytoscape.js graph for access package relationships
- Comprehensive export capabilities (PNG, Markdown, JSON)
- Enhanced HTML reports with light/dark theme toggle
- Developed in collaboration with Christian Frohn
- See [full changelog](CHANGELOG.md#110---2026-03-12) for complete details

---

## 📮 Support

For bugs, feature requests, or questions:
- 🐛 Open an [issue](https://github.com/Noble-Effeciency13/M365IdentityPosture/issues)
- 💬 Check [discussions](https://github.com/Noble-Effeciency13/M365IdentityPosture/discussions) for Q&A
- 🌐 Follow updates on [Chance of Security](https://chanceofsecurity.com)

---

**⚠️ Important Note**: This module performs read-only operations and does not modify any configurations in your tenant. Always review the generated reports and verify findings in your environment. Use the insights provided to enhance your security posture through informed decision-making.

**🔒 Security**: For security concerns or vulnerability reports, please email security@chanceofsecurity.com rather than using public issues.
