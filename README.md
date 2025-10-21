# code_base

[![Repo size](https://img.shields.io/github/repo-size/darlington-nwemeh/code_base)]()
[![Tech: SSIS | PowerShell | SQL](https://img.shields.io/badge/Tech-SSIS%20%7C%20PowerShell%20%7C%20SQL-blue)]()
[![Last commit](https://img.shields.io/github/last-commit/darlington-nwemeh/code_base)]()

**Repository purpose:** production-style ETL artifacts for ingesting and staging Salesforce + SQL Server data. Includes SSIS packages, connection managers, PowerShell deployment scripts, and SQL UDFs used in a staged + historical retention architecture. This README corrects and replaces the earlier draft to match the repository's *actual* files and layout.

---

## Table of Contents

- [About](#about)
- [Architecture Diagram](#architecture-diagram)
- [Repository Structure (actual)](#repository-structure-actual)
- [Key Components & Files (actual)](#key-components--files-actual)
- [Requirements](#requirements)
- [Setup & Local Testing](#setup--local-testing)
- [Deployment & Orchestration (accurate)](#deployment--orchestration-accurate)
- [Running / Scheduling](#running--scheduling)
- [Examples & Useful Snippets](#examples--useful-snippets)
- [Contributing](#contributing)
- [Contact](#contact)

---

## About

This repository contains the real assets used for Salesforce → SQL Server staging and history retention. The content is primarily at the repository root (not separated into `/ssis` `/powershell` folders). The README below reflects the actual filenames and flow present in the repository.

If any filenames or organization change in the repo later, tell me and I'll update this README to match.

---

## Architecture Diagram

The diagram below uses the exact high-level artifacts found in the repository (SSIS project + packages, PowerShell deployment script, connection managers, SQL UDF). GitHub renders Mermaid diagrams automatically in Markdown.

```mermaid
flowchart TB
  subgraph Sources
    SF[Salesforce API / Objects]
    SRCSQL[(Source SQL Server)]
  end

  subgraph Deployment ["Deployment & CI"]
    PS[PowerShell: SalesForceStagingHistoryLoadDeployment.ps1]
  end

  subgraph ETL ["SSIS Project & Packages"]
    DTProj[SalesForceStagingHistoryLoad.dtproj / .ispac]
    CM1[OLEDB_Source.conmgr]
    CM2[OLEDB_Target.conmgr]
    CM3[TaskFactorySalesForceConn[Task Factory Salesforce CM]]
    PkgMaster[StagingHistorySalesForceMasterPackage.dtsx]
    PkgLoad1[LoadTablePreStagingSalesForceContactStagingHistorySalesForceContactInitIncr.dtsx]
    PkgLoad2[LoadTablePreStagingSalesForceLSAAssignmentCStagingHistorySalesForceLSAAssignmentCInitIncr.dtsx]
    PkgLoad3[LoadTablePreStagingSalesForceMLISAccountCStagingHistorySalesForceMLISAccountCInitIncr.dtsx]
    SQLUDF[fn_clean_phone_numbers.sql]
  end

  subgraph SQLServer ["SQL Server (Pre-Staging / Staging / History / Reporting)"]
    Pre[(Pre-Staging Tables)]
    Stg[(Staging Tables)]
    Hist[(Staging History / Audit Tables)]
    Rep[(Reporting / DW)]
  end

  subgraph Orchestration ["Execution & Monitoring"]
    Agent[SQL Server Agent Jobs]
    Logs[SSISDB / Job Logs]
  end

  SF -->|API / Extract| PkgLoad1
  SRCSQL -->|Source reads| PkgLoad1
  PS -->|Deploys (.ispac / .dtsx)| DTProj
  DTProj --> CM1
  DTProj --> CM2
  DTProj --> CM3
  DTProj --> PkgMaster
  PkgMaster --> PkgLoad1
  PkgMaster --> PkgLoad2
  PkgMaster --> PkgLoad3
  PkgLoad1 -->|Writes| Pre
  PkgLoad2 -->|Transforms| Stg
  PkgLoad3 -->|Transforms| Stg
  SQLUDF -->|Used by| PkgLoad2
  Agent -->|Executes| PkgMaster
  Agent -->|Executes| PkgLoad1
  Agent --> Logs
  Logs --> Rep
  Hist --> Rep
  Stg --> Rep
```

---

## Repository Structure (actual)

**Files at repository root (selected):**

- `SalesForceStagingHistoryLoad.dtproj`  — SSIS project file
- `SalesForceStagingHistoryLoad.database` — DB project / metadata
- `SalesForceStagingHistoryLoadDeployment.ps1` — PowerShell deployment script
- `StagingHistorySalesForceMasterPackage.dtsx` — SSIS master package
- `LoadTablePreStagingSalesForceContactStagingHistorySalesForceContactInitIncr.dtsx` — ETL load package (Contact)
- `LoadTablePreStagingSalesForceLSAAssignmentCStagingHistorySalesForceLSAAssignmentCInitIncr.dtsx` — ETL load package (LSAAssignment)
- `LoadTablePreStagingSalesForceMLISAccountCStagingHistorySalesForceMLISAccountCInitIncr.dtsx` — ETL load package (MLISAccount)
- `Task Factory SalesForce.com Connection Manager.conmgr` — Task Factory Salesforce connection manager
- `OLEDB_Source.conmgr`, `OLEDB_Target.conmgr`, `OLEDB_StagingHistoryTarget.conmgr`, `OLEDB_ETLAudit.conmgr` — OLEDB connection manager files
- `Project.params` — SSIS parameters file
- `fn_clean_phone_numbers.sql` — SQL UDF for phone normalization
- `README.md` — existing README (this change will replace/update it)

> Use `View all files` on GitHub to see the full list — these are the principal artifacts used by the ETL pipeline.

---

## Key Components & Files (actual)

### SSIS Project & Packages
- **SalesForceStagingHistoryLoad.dtproj** — Visual Studio / SSDT project that groups packages and parameters.
- **StagingHistorySalesForceMasterPackage.dtsx** — master/control package that orchestrates child packages for loads and transforms.
- **LoadTablePreStaging...InitIncr.dtsx** (multiple) — incremental/initial load packages for various Salesforce object types (Contacts, LSA Assignments, MLIS Accounts, etc.).

### Connection Managers
- **OLEDB_*.conmgr** — database connection templates (source, staging/target, audit DB).
- **Task Factory SalesForce.com Connection Manager.conmgr** — Salesforce connector (Task Factory component) used to connect and extract Salesforce objects.

### Deployment Scripts
- **SalesForceStagingHistoryLoadDeployment.ps1** — PowerShell script used to deploy the SSIS project / packages to the target server/catalog and update environment parameters.

### SQL Helpers
- **fn_clean_phone_numbers.sql** — SQL helper UDF used for phone normalization/cleansing as part of transformations.

---

## Requirements (same as before)

- Visual Studio + SSDT (Integration Services)
- SQL Server (target versions compatible with SSIS packages)
- PowerShell 5.1+ (for deployment automation)
- SQL Server Agent (for job scheduling)
- Network access & credentials for Salesforce API / source DBs

---

## Setup & Local Testing (accurate)

1. **Clone the repo**
```bash
git clone https://github.com/darlington-nwemeh/code_base.git
cd code_base
```

2. **Open project in Visual Studio (SSDT)**  
Open `SalesForceStagingHistoryLoad.dtproj` and inspect packages and parameters in Visual Studio Integration Services project.

3. **Parameterize connection strings**  
Use `Project.params` to manage environment-specific values; replace secrets with parameter tokens and use secure storage during deployment.

4. **Local debug**  
Run `StagingHistorySalesForceMasterPackage.dtsx` and child packages in SSDT (debug mode) against a dev environment to validate behavior.

---

## Deployment & Orchestration (accurate)

- **Deployment:** run `SalesForceStagingHistoryLoadDeployment.ps1` to deploy the project to SSIS Catalog (SSISDB) or file system. The script handles uploading `.ispac` / `.dtsx` and binding environment variables.
- **Execution:** SQL Server Agent jobs are configured on the target SQL Server to call the deployed SSIS packages (master package or individual packages) on a schedule.
- **Monitoring:** check SSISDB (if using project deployment), SQL Agent job history, and package logging tables/files for success/failure and performance metrics.

**Example PowerShell invocation (adapt to your environment):**
```powershell
.\SalesForceStagingHistoryLoadDeployment.ps1 -SSISCatalogServer "sql-host" -ProjectPath ".\SalesForceStagingHistoryLoad.ispac" -EnvironmentName "Prod"
```

---

## Running / Scheduling (accurate)

- Initial/full loads: run master package to bootstrap pre-staging and full snapshots.
- Incremental loads: schedule `LoadTablePreStaging*InitIncr.dtsx` or master package via SQL Agent with appropriate intervals.
- Use logging and checks to ensure incremental logic and history retention behave as expected.

---

## Examples & Useful Snippets (actual)

**Sample UDF: `fn_clean_phone_numbers.sql`** (inspect the repo file for the exact implementation):
```sql
-- This repo contains fn_clean_phone_numbers.sql; open it for the exact logic used.
SELECT dbo.fn_clean_phone_numbers(phone_column) FROM stage.Contacts;
```

**PowerShell deployment snippet (see SalesForceStagingHistoryLoadDeployment.ps1 in repo for full logic):**
```powershell
.\SalesForceStagingHistoryLoadDeployment.ps1 -SSISCatalogServer "sql.example" -ProjectPath ".\SalesForceStagingHistoryLoad.ispac" -EnvironmentName "Dev"
```

---

## Contributing (accurate)

- Fork and open a branch (e.g., `feature/docs-update`).
- Keep secrets/credentials out of the repo; use `Project.params` for parameter placeholders and override at deployment time.
- Update `/README.md` and `/docs/runbook.md` with any process or operational changes.

---

## Contact

Maintainer: **Darlington Nwemeh**  
GitHub: `darlington-nwemeh/code_base`

