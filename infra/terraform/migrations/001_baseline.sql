-- MLflow manages its own tables via Alembic (`mlflow db upgrade`); this file only
-- satisfies the apc-schema migrator, which requires a migrations directory.
SELECT 1;
