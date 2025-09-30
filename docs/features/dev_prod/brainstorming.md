# Dev Prod Brainstorming Document

## Ideas
1. Clearly define schema version 1.0. 
2. Leverage Drift for data migrations.
3. For each new data version, push and test a migration.
4. Duplicate mixpanel, supabase tables, and sentry.  
5. Maintain different .env files with different keys.
6. Create an AppConfig/AppEnvironment service that controllers/services can call depending on dev/prod
7. Create dev/prod flavors
8. Create a dev mode.  Release internal builds in dev mode.  Production builds can be swapped to dev mode as needed.