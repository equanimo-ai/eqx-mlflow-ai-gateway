SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', 'mlflow_app', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mlflow_app')
\gexec

ALTER ROLE mlflow_app PASSWORD :'app_password';

GRANT mlflow_app TO CURRENT_USER;

SELECT 'CREATE DATABASE mlflow OWNER mlflow_app'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'mlflow')
\gexec

REVOKE ALL ON DATABASE mlflow FROM PUBLIC;
