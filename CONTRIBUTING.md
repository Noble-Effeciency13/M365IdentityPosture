# Contributing to M365IdentityPosture

First off, thank you for considering contributing to M365IdentityPosture! It's people like you that make this module a great tool for the Microsoft 365 security community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Pull Requests](#pull-requests)
  - [Adding New Reports](#adding-new-reports)
- [Development Setup](#development-setup)
- [Style Guidelines](#style-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Release Process](#release-process)

## 📜 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please be respectful and considerate in all interactions.

## 🤝 How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, please include:

- **Clear and descriptive title**
- **PowerShell version** (`$PSVersionTable`)
- **Module version** (`Get-Module M365IdentityPosture`)
- **Steps to reproduce**
- **Expected behavior**
- **Actual behavior**
- **Error messages** (full error with `$Error[0] | Format-List -Force`)
- **Tenant size** (approximate number of users/groups)
- **Relevant permissions** you have in the tenant

### 💡 Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use case** - Why is this enhancement needed?
- **Proposed solution** - How should it work?
- **Alternatives considered** - What other solutions did you consider?
- **Additional context** - Screenshots, mockups, or examples

### 🔧 Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the coding standards** (see below)
3. **Add tests** if applicable
4. **Update documentation** as needed
5. **Test your changes** thoroughly
6. **Submit a pull request** with a clear description

#### Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the CHANGELOG.md with your changes under "Unreleased"
3. Ensure all tests pass
4. Request review from maintainers
5. Address any feedback
6. Once approved, your PR will be merged

### 📊 Adding New Reports

When contributing a new report type, follow this structure:

#### 1. Create the Public Function

Create a new file in `Public/` folder:

```powershell
# Public/Invoke-YourNewReport.ps1
function Invoke-YourNewReport {
    <#
    .SYNOPSIS
        Brief description of what the report does.
    
    .DESCRIPTION
        Detailed description of the report functionality.
    
    .PARAMETER ParameterName
        Description of each parameter.
    
    .OUTPUTS
        What the function returns.
    
    .EXAMPLE
        Invoke-YourNewReport -TenantName "contoso"
    #>
    [CmdletBinding()]
    param(
        # Standard parameters following module conventions
        [Parameter()]
        [string]$TenantName,
        
        [Parameter()]
        [string]$OutputPath = "C:\Reports\YourReport",
        
        [Parameter()]
        [switch]$Quiet,
        
        # Add report-specific parameters here
    )
    
    # Implementation following module patterns
}
```

#### 2. Add Supporting Functions

Place helper functions in appropriate `Private/` subfolders:

- `YourNewReport/`  - Report specific functions
- `Authentication/` - Service connection functions
- `DataCollection/` - Data retrieval functions
- `DataProcessing/` - Data transformation functions
- `Orchestration/`  - Workflow coordination
- `ReportGeneration/` - HTML generation

#### 3. Update Module Manifest

Add your function to `FunctionsToExport` in `M365IdentityPosture.psd1`:

```powershell
FunctionsToExport = @(
    'Invoke-AuthContextInventoryReport',
    'Invoke-YourNewReport'  # Add your new function
)
```

#### 4. Documentation Requirements

- Complete comment-based help for all functions
- Update README.md with:
  - New report description in features section
  - Usage examples
  - Required permissions
- Add to CHANGELOG.md under "Unreleased"

## 🛠️ Development Setup

### Prerequisites

- PowerShell 7.0 or higher
- Git
- VS Code (recommended) with PowerShell extension
- Required PowerShell modules for testing

### Setting Up Your Environment

```powershell
# Clone your fork
git clone https://github.com/YourUsername/M365IdentityPosture.git
cd M365IdentityPosture

# Create a feature branch
git checkout -b feature/your-feature-name

# Install required modules for testing
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser

# Import the module for testing
Import-Module .\M365IdentityPosture.psd1 -Force
```

### VS Code Settings

Add these to your workspace settings (`.vscode/settings.json`):

```json
{
    "[powershell]": {
        "editor.tabSize": 4,
        "editor.insertSpaces": false,
        "editor.detectIndentation": false
    }
}
```

## 📐 Style Guidelines

### PowerShell Coding Standards

1. **Indentation**: Use tabs (not spaces)
   - 1 tab for comment-based help sections
   - 2 tabs for comment-based help content

2. **Naming Conventions**:
   - **Public functions**: `Verb-Noun` (approved verbs only)
   - **Private functions**: `Verb-NounDescriptive`
   - **Variables**: `camelCase` for local, `PascalCase` for script/global
   - **Parameters**: `PascalCase`

3. **Function Structure**:
   ```powershell
   function Get-ExampleFunction {
       <#
       .SYNOPSIS
           Brief description.
       
       .DESCRIPTION
           Detailed description.
       #>
       [CmdletBinding()]
       param(
           [Parameter(Mandatory)]
           [string]$RequiredParam,
           
           [Parameter()]
           [switch]$OptionalSwitch
       )
       
       begin {
           # Initialization
       }
       
       process {
           # Main logic
       }
       
       end {
           # Cleanup
       }
   }
   ```

4. **Error Handling**:
   - Use try/catch for external calls
   - Log errors appropriately
   - Provide meaningful error messages

5. **Comments**:
   - Use comment-based help for all functions
   - Inline comments for complex logic
   - Avoid obvious comments

### Commit Messages

Follow conventional commits format:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code formatting (no logic changes)
- `refactor:` Code restructuring
- `test:` Adding tests
- `chore:` Maintenance tasks

Example: `feat: add conditional access gap analysis report`

## 🧪 Testing

### Running Tests

```powershell
# Run smoke test
& .\Tests\SmokeTest.ps1

# Run Pester tests (if available)
Invoke-Pester -Path .\Tests\
```

### Writing Tests

Place test files in `Tests/` folder following the naming convention `*.Tests.ps1`:

```powershell
# Tests/YourFunction.Tests.ps1
Describe 'Get-YourFunction' {
    It 'Should return expected results' {
        # Test implementation
        $result = Get-YourFunction -Parameter "value"
        $result | Should -Not -BeNullOrEmpty
    }
}
```

## 📚 Documentation

### Required Documentation

1. **Comment-based help** for all functions
2. **README updates** for new features
3. **CHANGELOG entries** for all changes
4. **Examples** showing real-world usage
5. **Parameter descriptions** that are clear and complete

### Documentation Standards

- Use clear, concise language
- Include examples for complex functions
- Document any breaking changes prominently
- Keep README focused on usage, not implementation

## 🚀 Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. [ ] All tests pass
2. [ ] Documentation updated
3. [ ] CHANGELOG.md updated
4. [ ] Version bumped in .psd1
5. [ ] PR reviewed and approved
6. [ ] Merge to main
7. [ ] Create GitHub release
8. [ ] Automatic publish to PSGallery (via GitHub Action)

## 🙏 Recognition

Contributors will be recognized in:
- GitHub contributors page
- CHANGELOG.md for significant contributions
- README.md acknowledgments section

## 💬 Questions?

Feel free to:
- Open an issue for questions
- Start a discussion in GitHub Discussions
- Contact maintainers directly

Thank you for contributing to M365IdentityPosture! Your efforts help improve security reporting for the entire Microsoft 365 community.