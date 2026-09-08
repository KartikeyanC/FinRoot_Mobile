# drift_schemas/

Versioned snapshots of the local database schema (`lib/data/local/app_database.dart`).

`drift_schema_v1.json` is the initial schema (M4).

## When you change the schema

1. Edit `tables.dart` / add a table.
2. Bump `AppDatabase.schemaVersion` and add the upgrade step to `migration`
   (`onUpgrade`).
3. Dump the new snapshot:
   ```
   dart run drift_dev schema dump lib/data/local/app_database.dart drift_schemas/
   ```
4. Regenerate code: `dart run build_runner build`.
5. (When there is more than one version) generate the migration-test helpers
   and add a `SchemaVerifier` test:
   ```
   dart run drift_dev schema generate drift_schemas/ test/data/local/generated/
   ```

The snapshots are how a migration from an old install is verified without a
real device — do not delete old versions.
