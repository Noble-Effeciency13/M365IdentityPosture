# Changelog

All notable changes to the M365IdentityPosture module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Planned
- Role Assignment Auditing capabilities
- Conditional Access Gap Analysis
- Identity Protection Insights dashboard

## [1.1.0] - 2026-03-12
### Added
- **Access Package Documentor** - Interactive visualization and comprehensive documentation of Entitlement Management *(Developed in collaboration with Christian Frohn)*
  - Interactive Cytoscape.js graph visualization of access packages, catalogs, policies, and resources
  - Advanced filtering by catalog, package, policy, and resource type
  - Full-text search across all node labels
  - Export capabilities: PNG/JPEG (graph screenshots), Markdown (hierarchical documentation), JSON (structured data)
  - Light/Dark theme toggle for improved accessibility
  - Approval workflow visualization with multi-stage approval chains
  - Custom extension integration display
  - Resource role scope analysis
  - Policy configuration details (expiration, approval settings, questions, reviews)
  - Responsive layout with collapsible detail panels
  - Zoom controls and graph layout optimization

### Enhanced
- Module now supports dual reporting capabilities: Authentication Context Inventory and Access Package Documentor
- Improved HTML report generation with reusable graph visualization components
- Enhanced theme support with runtime switching
- Better cross-service data correlation
- Added version check on module import to notify users of available updates

### Acknowledgments
- Christian Frohn ([@ChrFrohn](https://github.com/ChrFrohn)) - Collaborative development of Access Package Documentor feature

### Technical Improvements
- Modular report architecture supporting multiple report types
- Cytoscape.js integration for advanced graph visualization
- Enhanced error handling for Graph API operations
- Optimized memory usage for large tenant environments
- Improved export functionality with multiple format support
- New `Test-ModuleVersion` function for PSGallery version checking

## [1.0.0] - 2025-10-21
### Added
- Initial release of M365IdentityPosture module
- **Authentication Context Inventory** - Complete discovery and analysis across Microsoft 365 services
- **Purview Integration** - Sensitivity label analysis with authentication context detection
- **Conditional Access Mapping** - Policy analysis with authentication context references
- **PIM Policy Detection**
  - Directory role management policies
  - Group-based PIM policies with role assignments
  - Azure resource PIM policies (optional)
- **SharePoint Site Analysis** - Direct authentication context assignments and label inheritance
- **Microsoft 365 Groups/Teams** - Sensitivity label tracking and context enforcement
- **Protected Actions (RBAC)** - Authentication context requirements for critical operations
- **Rich HTML Reporting** - Interactive dashboard with metrics and detailed inventory tables
- **Theme Support** - Runtime-switchable Light/Dark themes for better accessibility
- **Cross-Service Correlation** - Unified view of authentication contexts across all services

### Technical Features
- PowerShell 7+ optimized for performance and cross-platform support
- Modular architecture with clear separation of concerns
- Comprehensive error handling and detailed logging
- Progress reporting for long-running operations
- Memory-efficient processing suitable for large tenants
- Dynamic module loading to minimize resource usage
- Complete comment-based help documentation for all functions
- Tab-based code formatting standards

### Security
- Read-only operations ensure no tenant modifications
- Secure credential handling through native PowerShell mechanisms
- Minimal permission requirements documented

[1.1.0]: https://github.com/Noble-Effeciency13/M365IdentityPosture/releases/tag/v1.1.0
[1.0.0]: https://github.com/Noble-Effeciency13/M365IdentityPosture/releases/tag/v1.0.0