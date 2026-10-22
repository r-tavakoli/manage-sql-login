#  sp_manage_sql_login — Provision, Grant, Revoke & Audit SQL Logins

![SQL Server](https://img.shields.io/badge/SQL%20Server-2016%2B-blue?logo=microsoftsqlserver&logoColor=white)
![T-SQL](https://img.shields.io/badge/Language-T--SQL-CC2927)

A single stored procedure to **provision SQL Server logins**, **grant or revoke permissions** on schemas across one or more databases, and **enable or disable logins** — all while writing an audit trail to `dba.security.user_access_log`.


## 📋 Overview

| Property | Value |
|---|---|
| **Name** | `dba.security.sp_manage_sql_login` |
| **Purpose** | Manage SQL logins, schema permissions, and login state in one call |
| **Language** | T-SQL |
| **Database** | `dba` (schema `security`) |
| **Audit Table** | `dba.security.user_access_log` (auto-created on first run) |
| **Returns** | Result set of audit rows written in this run + return code (`0` = success, `1` = validation error, `2` = runtime error) |


## 🎯 What It Does

The SP behaves differently depending on the `@operation` parameter:

| `@operation` | Behaviour |
|---|---|
| `grant` | Creates the login if missing, creates the database user(s), then **grants** the permissions described by `@action` on each schema in each database. |
| `revoke` | **Revokes** the permissions described by `@action` on each schema in each database (the login is not dropped). |
| `disable_login` | Runs `ALTER LOGIN ... DISABLE`. Server-level only — `@db_list` and `@schema_list` are ignored. |
| `enable_login` | Runs `ALTER LOGIN ... ENABLE`. Server-level only — `@db_list` and `@schema_list` are ignored. |

For `grant` and `revoke`, the SP also ensures:

- The **database user** exists (created via `CREATE USER ... FOR LOGIN` if missing).
- **DB-level `CREATE TABLE / VIEW / PROCEDURE / FUNCTION`** permissions are granted (for `@action = alter` or `admin`) or revoked.
- Every action is **idempotent** — running the SP twice won't duplicate permissions or log rows for the same operation.
- Every action is **logged** to `dba.security.user_access_log`.


## 🧩 Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `@login_name` | `SYSNAME` | ✅ | — | SQL login name to manage |
| `@password` | `NVARCHAR(128)` | conditional | `NULL` | Password for the login. **Required only when the login does not exist yet** (i.e., first run of `grant`). If the login already exists, the value is **ignored** — the existing password is left unchanged. |
| `@db_list` | `NVARCHAR(MAX)` | ✅ for grant/revoke | `NULL` | Comma-separated list of databases (e.g., `N'db1,db2'`) |
| `@schema_list` | `NVARCHAR(MAX)` | ✅ for grant/revoke | `NULL` | Comma-separated list of schemas (e.g., `N'dbo,schema1,schema2'`) |
| `@action` | `NVARCHAR(20)` | ✅ | `read` | Permission profile: `read`, `write`, `alter`, `admin` |
| `@operation` | `NVARCHAR(20)` | ✅ | `grant` | DCL operation: `grant`, `revoke`, `disable_login`, `enable_login` |

### `@action` → Permission Mapping

| `@action` | Schema-level permissions granted/revoked | DB-level permissions (only for grant, `alter`/`admin`) |
|---|---|---|
| `read` | `SELECT`, `EXECUTE` | — |
| `write` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `EXECUTE` | — |
| `alter` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `ALTER`, `EXECUTE` | `CREATE TABLE`, `CREATE VIEW`, `CREATE PROCEDURE`, `CREATE FUNCTION` |
| `admin` | `CONTROL` | `CREATE TABLE`, `CREATE VIEW`, `CREATE PROCEDURE`, `CREATE FUNCTION` |


## 🚀 Usage Examples

### 1. Grant read access to `reader2`

```sql
EXEC dba.security.sp_manage_sql_login
    @login_name  = N'reader2',
    @password    = N'123',
    @db_list     = N'db1,db2',
    @schema_list = N'schema1,schema2,dbo',
    @action      = N'read',        -- read | write | alter
    @operation   = N'grant';       -- grant | revoke | disable_login | enable_login