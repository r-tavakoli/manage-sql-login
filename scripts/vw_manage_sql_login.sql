
USE dba
GO

CREATE VIEW security.vw_user_permission_last_state

AS

/*
A read-only view that collapses the append-only audit log into **one row per (user, database, schema, permission)** 
showing only the permissions that are **currently in effect**. It answers the question *"What can this login actually
do right now?"* without you having to reason about the full history of grants and revokes.
*/

WITH ranked AS
(
    SELECT
        login_name,
        database_name,
        schema_name,
        permission_name,
        action_level,
        grant_scope,
        operation_type,
        granted_at,
        ROW_NUMBER() OVER (
            PARTITION BY login_name, database_name,
                        ISNULL(schema_name, N'(none)'), permission_name
            ORDER BY log_id DESC
        ) AS rn
    FROM dba.security.user_access_log
)
SELECT
    login_name,
    database_name,
    schema_name,
    permission_name,
    action_level,
    grant_scope,
    operation_type AS current_state,
    granted_at    AS since
FROM ranked
WHERE rn = 1 AND operation_type = N'GRANT'          -- only effective grants
ORDER BY login_name, database_name, schema_name, permission_name;