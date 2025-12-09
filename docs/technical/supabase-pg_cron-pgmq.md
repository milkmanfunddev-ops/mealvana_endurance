# Supabase Background Job Processing with pg_cron and pgmq

## Executive Summary

This guide documents how to implement background job processing in Supabase using PostgreSQL's native extensions: **pg_cron** (cron scheduler) and **pgmq** (message queue). This pattern enables reliable, fault-tolerant processing of long-running tasks like bulk nutrition plan generation for imported workouts.

**Key Benefits**:
- **Native PostgreSQL** - No external infrastructure required
- **Guaranteed Delivery** - At-least-once message processing with automatic retries
- **Simple Integration** - Works seamlessly with existing Edge Functions
- **Zero Configuration** - Built into Supabase with dashboard management

## Table of Contents

1. [pg_cron Basics](#pg_cron-basics)
2. [pgmq Message Queue](#pgmq-message-queue)
3. [Integration Pattern](#integration-pattern)
4. [Deployment](#deployment)
5. [Monitoring and Debugging](#monitoring-and-debugging)
6. [Production Example: Nutrition Plan Queue](#production-example-nutrition-plan-queue)

---

## pg_cron Basics

### What is pg_cron?

pg_cron is a PostgreSQL extension that enables cron-based job scheduling directly in the database. It creates a `cron` schema with two key tables:
- `cron.job` - Stores job definitions
- `cron.job_run_details` - Records execution history

### Enabling pg_cron

**Option 1: Dashboard (Recommended)**
1. Navigate to **Integrations** in Supabase Dashboard
2. Find "Cron" and click **Enable**
3. Alternatively, go to **Database** → **Extensions** → Search "pg_cron"

**Option 2: SQL**
```sql
create extension if not exists pg_net;  -- Required for HTTP calls
create extension if not exists pg_cron;
```

### Version Requirements
- **Current Version**: pg_cron 1.6.4
- **Minimum Postgres**: 15.6.1.122+ recommended for bug fixes and auto-revive capabilities

### Scheduling Jobs

**Cron Syntax**
```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday=0)
│ │ │ │ │
* * * * *
```

**Common Patterns**
```sql
-- Every minute
'* * * * *'

-- Every 5 minutes
'*/5 * * * *'

-- Every 30 seconds (special Supabase syntax)
'30 seconds'

-- Every hour at minute 0
'0 * * * *'

-- Daily at midnight
'0 0 * * *'

-- Weekdays at 9 AM
'0 9 * * 1-5'
```

**Scheduling a Job**
```sql
-- Schedule a SQL command
select cron.schedule(
  'job-name',           -- Job identifier
  '*/5 * * * *',        -- Cron expression (every 5 minutes)
  $$ SELECT process_queue(); $$  -- SQL to execute
);

-- Schedule with options
select cron.schedule(
  'nightly-cleanup',
  '0 0 * * *',
  $$ DELETE FROM logs WHERE created_at < NOW() - INTERVAL '30 days'; $$
);
```

**Managing Jobs**
```sql
-- View all scheduled jobs
SELECT jobid, jobname, schedule, command
FROM cron.job;

-- Alter a job's schedule
SELECT cron.alter_job(
  job_id := 123,
  schedule := '*/10 * * * *'  -- Change to every 10 minutes
);

-- Unschedule (delete) a job
SELECT cron.unschedule('job-name');
-- Or by ID
SELECT cron.unschedule(123);
```

### Monitoring Job Execution

**Check Recent Job Runs**
```sql
-- View last 10 runs
SELECT
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;
```

**Find Failed Jobs (Last 5 Days)**
```sql
SELECT *
FROM cron.job_run_details
WHERE status NOT IN ('succeeded', 'running')
  AND start_time > NOW() - INTERVAL '5 days'
ORDER BY start_time DESC;
```

**Count Job Executions**
```sql
SELECT
  j.jobname,
  COUNT(*) as total_runs,
  SUM(CASE WHEN jrd.status = 'succeeded' THEN 1 ELSE 0 END) as successful_runs,
  SUM(CASE WHEN jrd.status = 'failed' THEN 1 ELSE 0 END) as failed_runs
FROM cron.job j
LEFT JOIN cron.job_run_details jrd ON j.jobid = jrd.jobid
WHERE jrd.start_time > NOW() - INTERVAL '24 hours'
GROUP BY j.jobname;
```

### Limitations and Best Practices

**Concurrency Limits**
- **Maximum 32 concurrent jobs** - Each uses a database connection
- **Recommended: 8 concurrent jobs** - Leave headroom for other connections
- Space out jobs to prevent connection exhaustion

**Execution Time**
- **Default Timeout**: ~10 minutes per job
- Long-running jobs may show timeout errors
- **Solution**: Wrap in database functions with custom timeouts

**Resource Management**
```sql
-- Example: Function with timeout
CREATE OR REPLACE FUNCTION long_running_job()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  SET statement_timeout = '30min';  -- Custom timeout
  -- Your logic here
END;
$$;
```

**Error Handling**
- Errors are logged to `cron.job_run_details`
- Add custom logging for better debugging:
```sql
CREATE OR REPLACE FUNCTION process_with_logging()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  RAISE LOG 'Starting process at %', NOW();
  -- Your logic
  RAISE LOG 'Completed process at %', NOW();
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG 'Error in process: %', SQLERRM;
    RAISE;  -- Re-throw for pg_cron to catch
END;
$$;
```

**Job Persistence**
- Jobs are stored in the database
- **Important**: During migrations/upgrades, you may need to recreate jobs
- **Recommendation**: Store job definitions in migration files

---

## pgmq Message Queue

### What is pgmq?

PGMQ (PostgreSQL Message Queue) is a lightweight message queue built entirely in PostgreSQL. It provides:
- **Guaranteed Delivery**: At-least-once message processing
- **Visibility Timeouts**: Automatic retry for failed processing
- **Exactly-Once Within Window**: No duplicate processing during visibility timeout
- **Native PostgreSQL**: No external dependencies (Redis, RabbitMQ, etc.)

### Enabling pgmq

**Prerequisites**
- PostgreSQL version **15.6.1.143 or higher**
- Older projects may need database upgrade

**Dashboard Setup (Recommended)**
1. Navigate to **Integrations** → **Queues**
2. Click **Enable pgmq extension**
3. Optionally enable "Expose Queues via PostgREST" for client-side access

**SQL Setup**
```sql
CREATE EXTENSION IF NOT EXISTS pgmq;
```

### Queue Architecture

When you create a queue, pgmq creates two tables:
- `pgmq.q_<queue_name>` - Active messages
- `pgmq.a_<queue_name>` - Archived (completed) messages

**Queue Types**:
1. **Basic Queue**: Durable logged tables (default, recommended)
2. **Unlogged Queue**: Faster but data lost on crash (use carefully)
3. **Partitioned Queue**: Coming soon for high-scale scenarios

### Creating Queues

**Via Dashboard**
1. Go to **Queues** page
2. Click **Add a new queue**
3. Enter queue name (lowercase, hyphens/underscores allowed)
4. Select queue type (Basic recommended)

**Via SQL**
```sql
-- Create a basic queue
SELECT pgmq.create('nutrition_plans');

-- Create an unlogged queue (faster, less durable)
SELECT pgmq.create_unlogged('high_volume_queue');

-- List all queues
SELECT queue_name FROM pgmq.list_queues();

-- Drop a queue
SELECT pgmq.drop_queue('queue_name');
```

### Enqueuing Messages

**Add Single Message**
```sql
-- Returns message ID
SELECT * FROM pgmq.send(
  queue_name => 'nutrition_plans',
  msg => '{"workout_id": "abc123", "user_id": "user-456"}'::jsonb
);
```

**Add Multiple Messages**
```sql
-- Batch send (more efficient)
SELECT * FROM pgmq.send_batch(
  queue_name => 'nutrition_plans',
  msgs => ARRAY[
    '{"workout_id": "abc123"}'::jsonb,
    '{"workout_id": "def456"}'::jsonb,
    '{"workout_id": "ghi789"}'::jsonb
  ]::jsonb[]
);
```

**Delayed Messages**
```sql
-- Send message that won't be visible for 5 minutes
SELECT * FROM pgmq.send(
  queue_name => 'nutrition_plans',
  msg => '{"workout_id": "abc123"}'::jsonb,
  delay => 300  -- seconds
);
```

### Dequeuing Messages

**Read Message (Visibility Timeout)**
```sql
-- Read up to 5 messages, invisible for 60 seconds
SELECT * FROM pgmq.read(
  queue_name => 'nutrition_plans',
  vt => 60,  -- Visibility timeout in seconds
  qty => 5   -- Number of messages to read
);

-- Returns:
-- msg_id (bigint)
-- read_ct (integer) - How many times this message was read
-- enqueued_at (timestamp)
-- vt (timestamp) - When message becomes visible again
-- message (jsonb) - Your message payload
```

**Read with Extended Wait**
```sql
-- Poll for up to 10 seconds if queue is empty
SELECT * FROM pgmq.read(
  queue_name => 'nutrition_plans',
  vt => 60,
  qty => 1,
  poll_timeout_s => 10  -- Wait up to 10 seconds for messages
);
```

**Pop Message (Read + Delete)**
```sql
-- Atomically read and delete (use when no retry needed)
SELECT * FROM pgmq.pop('nutrition_plans');
```

### Handling Message Completion

**Delete Message (Success)**
```sql
-- Call after successful processing
SELECT pgmq.delete(
  queue_name => 'nutrition_plans',
  msg_id => 12345
);
```

**Archive Message (Keep for Audit)**
```sql
-- Move to archive table instead of deleting
SELECT pgmq.archive(
  queue_name => 'nutrition_plans',
  msg_id => 12345
);

-- Archive also returns the archived message
SELECT * FROM pgmq.archive(
  queue_name => 'nutrition_plans',
  msg_id => 12345
);
```

**Batch Delete**
```sql
-- Delete multiple messages at once
SELECT * FROM pgmq.delete(
  queue_name => 'nutrition_plans',
  msg_ids => ARRAY[12345, 12346, 12347]
);
```

### Visibility Timeout & Retries

**How It Works**:
1. Consumer reads message with `vt => 60` (60-second visibility timeout)
2. Message becomes invisible to other consumers for 60 seconds
3. If consumer crashes or doesn't complete within 60 seconds:
   - Message automatically becomes visible again
   - Another consumer can pick it up
4. `read_ct` increments each time message is read

**Extending Visibility Timeout**
```sql
-- Extend timeout during long-running processing
SELECT pgmq.set_vt(
  queue_name => 'nutrition_plans',
  msg_id => 12345,
  vt_offset => 120  -- Extend by 2 more minutes
);
```

**Tracking Retry Attempts**
```sql
-- Check how many times message was attempted
SELECT msg_id, read_ct, message
FROM pgmq.read('nutrition_plans', 60, 10)
WHERE read_ct > 3;  -- Find messages failing repeatedly
```

**Implementing Max Retries**
```sql
-- Move to dead letter queue after too many attempts
WITH failed_messages AS (
  SELECT msg_id, message
  FROM pgmq.read('nutrition_plans', 60, 10)
  WHERE read_ct > 5  -- Max 5 attempts
)
INSERT INTO pgmq.q_nutrition_plans_dlq (message)
SELECT message FROM failed_messages
RETURNING (SELECT pgmq.delete('nutrition_plans', msg_id) FROM failed_messages);
```

### Monitoring Queue Health

**Queue Metrics**
```sql
-- Get comprehensive queue metrics
SELECT * FROM pgmq.metrics('nutrition_plans');

-- Returns:
-- queue_name
-- queue_length - Current messages in queue
-- newest_msg_age_sec - Age of newest message
-- oldest_msg_age_sec - Age of oldest message
-- total_messages - All-time message count
-- scrape_time - Current timestamp
```

**All Queues Metrics**
```sql
-- Metrics for all queues
SELECT * FROM pgmq.metrics_all();
```

**Custom Monitoring Queries**
```sql
-- Find stale messages (stuck in processing)
SELECT
  msg_id,
  read_ct,
  enqueued_at,
  EXTRACT(EPOCH FROM (NOW() - enqueued_at)) AS age_seconds,
  message
FROM pgmq.q_nutrition_plans
WHERE vt < NOW()  -- Currently visible
  AND enqueued_at < NOW() - INTERVAL '1 hour'
ORDER BY enqueued_at;

-- Queue depth over time (requires periodic logging)
CREATE TABLE IF NOT EXISTS queue_depth_history (
  queue_name TEXT,
  depth INTEGER,
  measured_at TIMESTAMP DEFAULT NOW()
);

-- Log queue depth periodically (via cron)
INSERT INTO queue_depth_history (queue_name, depth)
SELECT queue_name, queue_length
FROM pgmq.metrics_all();
```

### Failure Handling Best Practices

**Dead Letter Queue Pattern**
```sql
-- Create dead letter queue for failed messages
SELECT pgmq.create('nutrition_plans_dlq');

-- Worker function with error handling
CREATE OR REPLACE FUNCTION process_nutrition_plan_queue()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  msg RECORD;
  max_retries INT := 5;
BEGIN
  -- Read messages
  FOR msg IN
    SELECT * FROM pgmq.read('nutrition_plans', vt => 60, qty => 10)
  LOOP
    BEGIN
      -- Check retry limit
      IF msg.read_ct > max_retries THEN
        -- Move to DLQ
        PERFORM pgmq.send('nutrition_plans_dlq', msg.message);
        PERFORM pgmq.delete('nutrition_plans', msg.msg_id);
        RAISE LOG 'Moved message % to DLQ after % attempts', msg.msg_id, msg.read_ct;
        CONTINUE;
      END IF;

      -- Process message (your logic here)
      PERFORM generate_nutrition_plan(msg.message->>'workout_id');

      -- Success - delete message
      PERFORM pgmq.delete('nutrition_plans', msg.msg_id);
      RAISE LOG 'Successfully processed message %', msg.msg_id;

    EXCEPTION
      WHEN OTHERS THEN
        -- Log error but let message retry
        RAISE LOG 'Error processing message %: %', msg.msg_id, SQLERRM;
        -- Message will automatically retry after visibility timeout
    END;
  END LOOP;
END;
$$;
```

---

## Integration Pattern

### Calling Edge Functions from pg_cron

This is the core pattern for triggering background jobs that need to call existing Edge Functions.

### Step 1: Secure Service Role Key Storage

**Using Supabase Vault (Recommended)**
```sql
-- Store service role key in Vault (via Dashboard or SQL)
-- Dashboard: Settings → Vault → Add Secret
-- Name: supabase_service_key
-- Value: your-service-role-key

-- Create function to retrieve key
CREATE OR REPLACE FUNCTION private.supabase_service_key()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  secret_value TEXT;
BEGIN
  SELECT decrypted_secret INTO secret_value
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_key';
  RETURN secret_value;
END;
$$;
```

### Step 2: Create Database Function to Call Edge Function

**Basic Pattern**
```sql
CREATE OR REPLACE FUNCTION call_edge_function_basic()
RETURNS void LANGUAGE sql AS $$
  SELECT net.http_post(
    url := 'https://your-project-ref.supabase.co/functions/v1/your-function',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || private.supabase_service_key(),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$;
```

**Advanced Pattern with Error Handling**
```sql
CREATE OR REPLACE FUNCTION call_edge_function_robust(
  function_name TEXT,
  payload JSONB DEFAULT '{}'::jsonb
)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  response_id BIGINT;
  base_url TEXT;
BEGIN
  -- Get project URL (assumes it's stored in a config table or env)
  base_url := current_setting('app.supabase_url', true);

  -- Make async HTTP request
  SELECT id INTO response_id FROM net.http_post(
    url := base_url || '/functions/v1/' || function_name,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || private.supabase_service_key(),
      'Content-Type', 'application/json'
    ),
    body := payload
  );

  RAISE LOG 'Called Edge Function % with request ID %', function_name, response_id;

EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG 'Error calling Edge Function %: %', function_name, SQLERRM;
    RAISE;
END;
$$;
```

### Step 3: Schedule the Cron Job

```sql
-- Schedule to run every 30 seconds
SELECT cron.schedule(
  'process-nutrition-plan-queue',
  '30 seconds',
  $$ SELECT call_edge_function_robust('nutrition-plan-worker', '{}'::jsonb); $$
);

-- Or use standard cron syntax for every minute
SELECT cron.schedule(
  'process-nutrition-plan-queue',
  '* * * * *',
  $$ SELECT process_nutrition_plan_queue(); $$
);
```

### Alternative: Disable JWT Verification

If you don't want to use service role keys:

1. Go to **Edge Functions** in Dashboard
2. Select your function
3. Scroll to **Security** section
4. Toggle off **Enforce JWT Verification**

**Security Implications**:
- Function becomes publicly accessible
- Add custom authentication in function code
- Check for custom header or secret

```typescript
// In Edge Function
Deno.serve(async (req) => {
  // Custom auth check
  const secret = req.headers.get('X-Cron-Secret');
  if (secret !== Deno.env.get('CRON_SECRET')) {
    return new Response('Unauthorized', { status: 401 });
  }

  // Process request
  // ...
});
```

### Complete Queue Worker Pattern

**Database Setup**
```sql
-- 1. Create queue
SELECT pgmq.create('nutrition_plans');

-- 2. Create worker function
CREATE OR REPLACE FUNCTION process_nutrition_plan_queue()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM call_edge_function_robust(
    'nutrition-plan-worker',
    '{}'::jsonb
  );
END;
$$;

-- 3. Schedule cron job
SELECT cron.schedule(
  'nutrition-plan-worker',
  '30 seconds',
  $$ SELECT process_nutrition_plan_queue(); $$
);
```

**Edge Function (nutrition-plan-worker)**
```typescript
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { db: { schema: "pgmq_public" } }
  );

  try {
    // Read up to 5 messages, 60-second visibility timeout
    const { data: messages, error: readError } = await supabase.rpc("read", {
      queue_name: "nutrition_plans",
      vt: 60,
      qty: 5,
    });

    if (readError) throw readError;
    if (!messages || messages.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    let processed = 0;
    let errors = 0;

    for (const msg of messages) {
      try {
        const { workout_id, user_id } = msg.message;

        // Call your existing nutrition plan generation function
        const { error: planError } = await supabase.functions.invoke(
          "generate-ai-nutrition-plan",
          {
            body: { workout_id, user_id },
          }
        );

        if (planError) throw planError;

        // Success - delete message
        await supabase.rpc("delete", {
          queue_name: "nutrition_plans",
          msg_id: msg.msg_id,
        });

        processed++;
      } catch (error) {
        console.error(`Error processing message ${msg.msg_id}:`, error);
        errors++;

        // Check if max retries reached
        if (msg.read_ct >= 5) {
          // Move to DLQ
          await supabase.rpc("send", {
            queue_name: "nutrition_plans_dlq",
            msg: msg.message,
          });
          await supabase.rpc("delete", {
            queue_name: "nutrition_plans",
            msg_id: msg.msg_id,
          });
          console.log(`Moved message ${msg.msg_id} to DLQ after ${msg.read_ct} attempts`);
        }
        // Otherwise message will retry automatically after visibility timeout
      }
    }

    return new Response(
      JSON.stringify({ processed, errors, total: messages.length }),
      {
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Worker error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
```

---

## Deployment

### Local Development Setup

**Prerequisites**
```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Initialize Supabase in your project
supabase init
```

**Local Database Setup**
```sql
-- supabase/migrations/YYYYMMDDHHMMSS_setup_background_jobs.sql

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create queues
SELECT pgmq.create('nutrition_plans');
SELECT pgmq.create('nutrition_plans_dlq');

-- Create service key retrieval function
CREATE OR REPLACE FUNCTION private.supabase_service_key()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  secret_value TEXT;
BEGIN
  SELECT decrypted_secret INTO secret_value
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_key';
  RETURN secret_value;
END;
$$;

-- Create Edge Function caller
CREATE OR REPLACE FUNCTION call_nutrition_plan_worker()
RETURNS void LANGUAGE sql AS $$
  SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/nutrition-plan-worker',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || private.supabase_service_key(),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$;

-- Schedule cron job
SELECT cron.schedule(
  'nutrition-plan-worker',
  '30 seconds',
  $$ SELECT call_nutrition_plan_worker(); $$
);
```

**Known Issue: Local pg_cron Setup**
- pg_cron may fail locally with "can only create extension in database postgres"
- **Workaround**: Set `cron.database_name = 'postgres'` in `postgresql.conf`
- **Alternative**: Test cron jobs in cloud development environment

### Production Deployment via Supabase CLI

**Step 1: Create Migration**
```bash
# Generate new migration file
supabase migration new setup_background_jobs

# Edit the generated file in supabase/migrations/
# Add your queue setup, functions, and cron schedules
```

**Step 2: Deploy to Remote**
```bash
# Link to your Supabase project
supabase link --project-ref your-project-ref

# Push migrations to remote database
supabase db push

# Deploy Edge Functions
supabase functions deploy nutrition-plan-worker
```

**Step 3: Configure Vault Secrets**
```bash
# Set service role key in Vault (do this once)
# Via Dashboard: Settings → Vault → Add Secret
# Name: supabase_service_key
# Value: <your-service-role-key>
```

### Deployment via Dashboard

**Enable Extensions**
1. Database → Extensions
2. Enable: `pg_cron`, `pg_net`, `pgmq`

**Create Queues**
1. Integrations → Queues
2. Add new queue: "nutrition_plans"
3. Add new queue: "nutrition_plans_dlq"

**Set Up Vault Secret**
1. Settings → Vault
2. Add secret: `supabase_service_key` = your-service-role-key

**Create Database Functions**
1. SQL Editor → New Query
2. Paste your function definitions
3. Run

**Schedule Cron Job**
1. Integrations → Cron
2. Add new job
3. Set schedule, command, or Edge Function

### CI/CD Deployment

**GitHub Actions Example**
```yaml
name: Deploy Supabase

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Deploy migrations
        run: |
          supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
          supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - name: Deploy Edge Functions
        run: |
          supabase functions deploy nutrition-plan-worker
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

### Environment Configuration

**Development vs Production**
```sql
-- Store environment-specific URLs in database
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  environment TEXT NOT NULL DEFAULT 'production'
);

-- Insert config
INSERT INTO app_config (key, value, environment) VALUES
  ('supabase_url', 'https://dev-project.supabase.co', 'development'),
  ('supabase_url', 'https://prod-project.supabase.co', 'production');

-- Use in functions
CREATE OR REPLACE FUNCTION get_config(config_key TEXT)
RETURNS TEXT LANGUAGE sql AS $$
  SELECT value FROM app_config
  WHERE key = config_key
    AND environment = current_setting('app.environment', true);
$$;
```

---

## Monitoring and Debugging

### pg_cron Monitoring

**Check Job Status**
```sql
-- View all scheduled jobs
SELECT
  jobid,
  jobname,
  schedule,
  active,
  nodename,
  nodeport
FROM cron.job
ORDER BY jobid;
```

**Recent Executions**
```sql
-- Last 20 job runs with status
SELECT
  j.jobname,
  jrd.runid,
  jrd.status,
  jrd.return_message,
  jrd.start_time,
  jrd.end_time,
  EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time)) AS duration_seconds
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
ORDER BY jrd.start_time DESC
LIMIT 20;
```

**Error Analysis**
```sql
-- Failed jobs in last 24 hours
SELECT
  j.jobname,
  COUNT(*) AS failure_count,
  ARRAY_AGG(jrd.return_message) AS error_messages,
  MAX(jrd.start_time) AS last_failure
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE jrd.status = 'failed'
  AND jrd.start_time > NOW() - INTERVAL '24 hours'
GROUP BY j.jobname
ORDER BY failure_count DESC;
```

**Job Performance Metrics**
```sql
-- Average execution time by job
SELECT
  j.jobname,
  COUNT(*) AS total_runs,
  AVG(EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time))) AS avg_duration_seconds,
  MIN(EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time))) AS min_duration,
  MAX(EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time))) AS max_duration
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE jrd.status = 'succeeded'
  AND jrd.start_time > NOW() - INTERVAL '7 days'
GROUP BY j.jobname;
```

**Check if Cron Scheduler is Running**
```sql
-- Verify pg_cron process is active
SELECT application_name, state, query_start, query
FROM pg_stat_activity
WHERE application_name = 'pg_cron';
```

### pgmq Monitoring

**Queue Depth Dashboard**
```sql
-- Current state of all queues
SELECT
  queue_name,
  queue_length AS current_depth,
  oldest_msg_age_sec,
  newest_msg_age_sec,
  total_messages
FROM pgmq.metrics_all()
ORDER BY queue_length DESC;
```

**Message Retry Analysis**
```sql
-- Messages being retried frequently
SELECT
  msg_id,
  read_ct AS retry_count,
  EXTRACT(EPOCH FROM (NOW() - enqueued_at)) AS age_seconds,
  message->'workout_id' AS workout_id
FROM pgmq.q_nutrition_plans
WHERE read_ct > 2
ORDER BY read_ct DESC, enqueued_at;
```

**Stuck Messages Detection**
```sql
-- Messages that are visible but very old (potential issues)
SELECT
  msg_id,
  read_ct,
  enqueued_at,
  vt AS becomes_visible_at,
  CASE
    WHEN vt < NOW() THEN 'VISIBLE'
    ELSE 'INVISIBLE'
  END AS visibility_status,
  message
FROM pgmq.q_nutrition_plans
WHERE enqueued_at < NOW() - INTERVAL '10 minutes'
ORDER BY enqueued_at;
```

**Dead Letter Queue Monitoring**
```sql
-- Check DLQ for failed messages
SELECT
  msg_id,
  enqueued_at,
  message->'workout_id' AS workout_id,
  message->'error' AS error_info
FROM pgmq.q_nutrition_plans_dlq
ORDER BY enqueued_at DESC
LIMIT 50;
```

**Queue Throughput**
```sql
-- Archive table shows completed messages
SELECT
  DATE_TRUNC('hour', archived_at) AS hour,
  COUNT(*) AS messages_completed
FROM pgmq.a_nutrition_plans
WHERE archived_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;
```

### Dashboard Monitoring

**Supabase Dashboard Features**:
- **Cron Jobs Page**: View job schedules and execution history
- **Queues Page**: Monitor queue depth and message flow
- **Logs Explorer**: Search for Edge Function logs
- **Database Logs**: View PostgreSQL logs for function errors

**Enable Enhanced Logging in Edge Functions**
```typescript
// Add structured logging
console.log(JSON.stringify({
  timestamp: new Date().toISOString(),
  level: 'info',
  message: 'Processing message',
  msg_id: msg.msg_id,
  workout_id: msg.message.workout_id,
  read_ct: msg.read_ct
}));
```

### Creating Custom Monitoring Views

**Comprehensive Job Health View**
```sql
CREATE OR REPLACE VIEW job_health AS
SELECT
  j.jobname,
  j.schedule,
  j.active,
  (
    SELECT COUNT(*)
    FROM cron.job_run_details jrd
    WHERE jrd.jobid = j.jobid
      AND jrd.start_time > NOW() - INTERVAL '1 hour'
  ) AS runs_last_hour,
  (
    SELECT COUNT(*)
    FROM cron.job_run_details jrd
    WHERE jrd.jobid = j.jobid
      AND jrd.status = 'failed'
      AND jrd.start_time > NOW() - INTERVAL '1 hour'
  ) AS failures_last_hour,
  (
    SELECT MAX(start_time)
    FROM cron.job_run_details jrd
    WHERE jrd.jobid = j.jobid
  ) AS last_run,
  (
    SELECT status
    FROM cron.job_run_details jrd
    WHERE jrd.jobid = j.jobid
    ORDER BY start_time DESC
    LIMIT 1
  ) AS last_status
FROM cron.job j;

-- Query the view
SELECT * FROM job_health;
```

**Queue Health View**
```sql
CREATE OR REPLACE VIEW queue_health AS
SELECT
  m.queue_name,
  m.queue_length,
  m.oldest_msg_age_sec,
  CASE
    WHEN m.queue_length = 0 THEN 'empty'
    WHEN m.oldest_msg_age_sec > 3600 THEN 'stale_messages'
    WHEN m.queue_length > 1000 THEN 'backlog'
    ELSE 'healthy'
  END AS health_status,
  (
    SELECT COUNT(*)
    FROM pg_tables
    WHERE schemaname = 'pgmq'
      AND tablename = 'q_' || m.queue_name
  ) AS queue_exists,
  m.scrape_time
FROM pgmq.metrics_all() m;

-- Query the view
SELECT * FROM queue_health WHERE health_status != 'healthy';
```

### Alerting Strategies

**PostgreSQL NOTIFY for Critical Events**
```sql
-- Create alert function
CREATE OR REPLACE FUNCTION alert_on_stuck_messages()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  stuck_count INT;
BEGIN
  SELECT COUNT(*) INTO stuck_count
  FROM pgmq.q_nutrition_plans
  WHERE enqueued_at < NOW() - INTERVAL '30 minutes'
    AND read_ct > 5;

  IF stuck_count > 0 THEN
    PERFORM pg_notify(
      'queue_alerts',
      json_build_object(
        'alert_type', 'stuck_messages',
        'queue_name', 'nutrition_plans',
        'count', stuck_count,
        'timestamp', NOW()
      )::text
    );
  END IF;
END;
$$;

-- Schedule alert check
SELECT cron.schedule(
  'check-stuck-messages',
  '*/5 * * * *',  -- Every 5 minutes
  $$ SELECT alert_on_stuck_messages(); $$
);
```

---

## Production Example: Nutrition Plan Queue

### Use Case
When users import workouts from Final Surge, we need to bulk-generate nutrition plans for each workout. This process:
- Can take 10-30 seconds per workout (AI generation)
- Should not block the import response
- Needs retry logic for API failures
- Should process one at a time to avoid rate limits

### Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (User Import)  │
└────────┬────────┘
         │
         │ 1. HTTP POST
         ▼
┌─────────────────────────┐
│  Edge Function:         │
│  import-final-surge     │
│  - Save workouts to DB  │
│  - Enqueue to pgmq      │
└─────────────────────────┘
         │
         │ 2. Messages enqueued
         ▼
┌─────────────────────────┐
│  pgmq Queue:            │
│  nutrition_plans        │
│  - One msg per workout  │
└─────────────────────────┘
         │
         │ 3. Every 30 seconds
         ▼
┌─────────────────────────┐
│  pg_cron Job:           │
│  nutrition-plan-worker  │
│  - Calls Edge Function  │
└─────────────────────────┘
         │
         │ 4. HTTP POST
         ▼
┌─────────────────────────────────┐
│  Edge Function:                 │
│  nutrition-plan-worker          │
│  - Read from queue (1 at a time)│
│  - Call generate-ai-nutrition   │
│  - Delete on success            │
│  - Retry on failure (auto)      │
└─────────────────────────────────┘
         │
         │ 5. Invoke existing function
         ▼
┌─────────────────────────────────┐
│  Edge Function:                 │
│  generate-ai-nutrition-plan     │
│  - AI generation logic          │
│  - Save to database             │
└─────────────────────────────────┘
```

### Implementation

#### Step 1: Database Migration

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_nutrition_plan_queue.sql

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create main queue
SELECT pgmq.create('nutrition_plans');

-- Create dead letter queue for failures
SELECT pgmq.create('nutrition_plans_dlq');

-- Store service role key in Vault (do this via Dashboard first!)
-- Settings → Vault → Add Secret
-- Name: supabase_service_key
-- Value: <your-service-role-key>

-- Function to retrieve service key from Vault
CREATE OR REPLACE FUNCTION private.supabase_service_key()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  secret_value TEXT;
BEGIN
  SELECT decrypted_secret INTO secret_value
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_key';
  RETURN secret_value;
END;
$$;

-- Function to call Edge Function worker
CREATE OR REPLACE FUNCTION call_nutrition_plan_worker()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT net.http_post(
    url := current_setting('app.supabase_url', true) || '/functions/v1/nutrition-plan-worker',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || private.supabase_service_key(),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$;

-- Schedule cron job to run every 30 seconds
SELECT cron.schedule(
  'nutrition-plan-worker',
  '30 seconds',
  $$ SELECT call_nutrition_plan_worker(); $$
);

-- Set the app.supabase_url config (replace with your project URL)
-- Run this once after migration:
-- ALTER DATABASE postgres SET app.supabase_url = 'https://your-project-ref.supabase.co';
```

#### Step 2: Edge Function - Worker

```typescript
// supabase/functions/nutrition-plan-worker/index.ts

import { createClient } from "jsr:@supabase/supabase-js@2";

interface QueueMessage {
  msg_id: number;
  read_ct: number;
  enqueued_at: string;
  vt: string;
  message: {
    workout_id: string;
    user_id: string;
    device_id: string;
  };
}

Deno.serve(async (req) => {
  const startTime = Date.now();

  // Initialize Supabase client with pgmq_public schema
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { db: { schema: "pgmq_public" } }
  );

  try {
    console.log("Starting nutrition plan worker");

    // Read ONE message from queue (process serially to avoid rate limits)
    const { data: messages, error: readError } = await supabase.rpc("read", {
      queue_name: "nutrition_plans",
      vt: 300, // 5-minute visibility timeout (allows time for AI generation)
      qty: 1, // Process one at a time
    });

    if (readError) {
      console.error("Error reading from queue:", readError);
      throw readError;
    }

    if (!messages || messages.length === 0) {
      console.log("No messages in queue");
      return new Response(
        JSON.stringify({
          success: true,
          processed: 0,
          message: "Queue is empty",
        }),
        {
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const msg = messages[0] as QueueMessage;
    const { workout_id, user_id, device_id } = msg.message;

    console.log(`Processing message ${msg.msg_id} for workout ${workout_id}`, {
      read_ct: msg.read_ct,
      enqueued_at: msg.enqueued_at,
    });

    try {
      // Call existing nutrition plan generation Edge Function
      const { data: planData, error: planError } = await supabase.functions.invoke(
        "generate-ai-nutrition-plan",
        {
          body: {
            workout_id,
            user_id,
            device_id,
          },
        }
      );

      if (planError) throw planError;

      console.log(`Successfully generated nutrition plan for workout ${workout_id}`);

      // Success - delete message from queue
      const { error: deleteError } = await supabase.rpc("delete", {
        queue_name: "nutrition_plans",
        msg_id: msg.msg_id,
      });

      if (deleteError) {
        console.error("Error deleting message:", deleteError);
        // Don't throw - plan was generated successfully
      }

      const duration = Date.now() - startTime;

      return new Response(
        JSON.stringify({
          success: true,
          processed: 1,
          workout_id,
          msg_id: msg.msg_id,
          duration_ms: duration,
        }),
        {
          headers: { "Content-Type": "application/json" },
        }
      );
    } catch (processingError) {
      console.error(`Error processing message ${msg.msg_id}:`, processingError);

      // Check if max retries reached (5 attempts)
      const MAX_RETRIES = 5;
      if (msg.read_ct >= MAX_RETRIES) {
        console.log(`Moving message ${msg.msg_id} to DLQ after ${msg.read_ct} attempts`);

        // Move to dead letter queue
        const dlqMessage = {
          ...msg.message,
          error: processingError.message,
          failed_at: new Date().toISOString(),
          attempts: msg.read_ct,
        };

        await supabase.rpc("send", {
          queue_name: "nutrition_plans_dlq",
          msg: dlqMessage,
        });

        // Delete from main queue
        await supabase.rpc("delete", {
          queue_name: "nutrition_plans",
          msg_id: msg.msg_id,
        });

        return new Response(
          JSON.stringify({
            success: false,
            processed: 0,
            moved_to_dlq: true,
            msg_id: msg.msg_id,
            error: processingError.message,
          }),
          {
            status: 500,
            headers: { "Content-Type": "application/json" },
          }
        );
      }

      // Message will automatically retry after visibility timeout expires
      console.log(`Message ${msg.msg_id} will retry (attempt ${msg.read_ct + 1})`);

      return new Response(
        JSON.stringify({
          success: false,
          processed: 0,
          will_retry: true,
          msg_id: msg.msg_id,
          retry_attempt: msg.read_ct + 1,
          error: processingError.message,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
  } catch (error) {
    console.error("Worker error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
```

#### Step 3: Modify Import Function to Enqueue

```typescript
// supabase/functions/import-final-surge/index.ts

// ... existing imports and setup ...

// After saving workouts to database:

// Enqueue nutrition plan generation for each workout
const supabaseQueue = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { db: { schema: "pgmq_public" } }
);

for (const workout of savedWorkouts) {
  await supabaseQueue.rpc("send", {
    queue_name: "nutrition_plans",
    msg: {
      workout_id: workout.id,
      user_id: userId,
      device_id: deviceId,
    },
  });
}

console.log(`Enqueued ${savedWorkouts.length} nutrition plan generation jobs`);
```

#### Step 4: Configure Database Settings

```sql
-- Run this once in SQL Editor after deploying migration
ALTER DATABASE postgres SET app.supabase_url = 'https://your-project-ref.supabase.co';
```

#### Step 5: Deploy

```bash
# Deploy Edge Functions
supabase functions deploy nutrition-plan-worker
supabase functions deploy import-final-surge

# Push database migrations
supabase db push

# Verify setup
supabase functions list
```

#### Step 6: Add Vault Secret

1. Go to **Settings** → **Vault** in Dashboard
2. Click **Add Secret**
3. Name: `supabase_service_key`
4. Value: Your service role key (from Settings → API)
5. Save

### Monitoring Queries

```sql
-- Check queue depth
SELECT queue_length, oldest_msg_age_sec
FROM pgmq.metrics('nutrition_plans');

-- Check recent cron executions
SELECT
  status,
  start_time,
  end_time,
  return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'nutrition-plan-worker')
ORDER BY start_time DESC
LIMIT 10;

-- Check DLQ for failed jobs
SELECT * FROM pgmq.q_nutrition_plans_dlq ORDER BY enqueued_at DESC;

-- Check messages with high retry counts
SELECT
  msg_id,
  read_ct,
  enqueued_at,
  message->'workout_id' as workout_id
FROM pgmq.q_nutrition_plans
WHERE read_ct > 2
ORDER BY read_ct DESC;
```

### Testing

```sql
-- Manually enqueue a test message
SELECT pgmq.send(
  'nutrition_plans',
  '{"workout_id": "test-123", "user_id": "user-456", "device_id": "dev-789"}'::jsonb
);

-- Verify it was enqueued
SELECT * FROM pgmq.metrics('nutrition_plans');

-- Watch it get processed (check every 30 seconds)
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'nutrition-plan-worker')
ORDER BY start_time DESC
LIMIT 1;
```

### Troubleshooting

**Queue Not Processing**
```sql
-- Check if cron job is active
SELECT * FROM cron.job WHERE jobname = 'nutrition-plan-worker';

-- Check recent cron errors
SELECT * FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC
LIMIT 5;

-- Manually trigger worker to test
SELECT call_nutrition_plan_worker();
```

**Messages Stuck in Queue**
```sql
-- Find stuck messages
SELECT
  msg_id,
  read_ct,
  enqueued_at,
  EXTRACT(EPOCH FROM (NOW() - enqueued_at)) as age_seconds
FROM pgmq.q_nutrition_plans
WHERE enqueued_at < NOW() - INTERVAL '10 minutes';

-- Reset visibility timeout to retry immediately
SELECT pgmq.set_vt('nutrition_plans', msg_id, 0)
FROM pgmq.q_nutrition_plans
WHERE msg_id = <stuck_msg_id>;
```

**High Failure Rate**
```sql
-- Inspect DLQ messages
SELECT
  message,
  enqueued_at
FROM pgmq.q_nutrition_plans_dlq
ORDER BY enqueued_at DESC
LIMIT 10;

-- Check Edge Function logs in Dashboard
-- Logs Explorer → Filter by function name: "nutrition-plan-worker"
```

---

## Additional Resources

### Documentation
- [Supabase Cron Documentation](https://supabase.com/docs/guides/cron)
- [Supabase Queues Documentation](https://supabase.com/docs/guides/queues)
- [pg_cron GitHub Repository](https://github.com/citusdata/pg_cron)
- [pgmq GitHub Repository](https://github.com/pgmq/pgmq)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)
- [Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions)

### Community Examples
- [Build Queue Worker using Supabase Cron, Queue and Edge Function](https://dev.to/suciptoid/build-queue-worker-using-supabase-cron-queue-and-edge-function-19di)
- [How to Set Up Cron Jobs with Supabase Edge Functions Using pg_cron](https://medium.com/@samuelmpwanyi/how-to-set-up-cron-jobs-with-supabase-edge-functions-using-pg-cron-a0689da81362)
- [Supabase pg_cron Debugging Guide](https://supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide-n1KTaz)

### Key Takeaways

1. **pg_cron + pgmq + Edge Functions** = Powerful background job system with no external dependencies
2. **Visibility timeouts** provide automatic retry logic without additional code
3. **Dead letter queues** handle persistent failures gracefully
4. **Service role keys** via Vault enable secure Edge Function invocation from cron jobs
5. **Serial processing** (qty=1) prevents rate limit issues for API-heavy tasks
6. **Built-in monitoring** via `cron.job_run_details` and `pgmq.metrics_all()`
7. **Dashboard management** makes setup and monitoring accessible to non-SQL users
8. **Migration-based deployment** enables version control and reproducible setups

---

## Sources

- [Supabase Cron Documentation](https://supabase.com/docs/guides/cron)
- [pg_cron Extension Documentation](https://supabase.com/docs/guides/database/extensions/pg_cron)
- [Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions)
- [PGMQ Extension Documentation](https://supabase.com/docs/guides/queues/pgmq)
- [Supabase Queues Guide](https://supabase.com/docs/guides/queues)
- [Supabase Queues Quickstart](https://supabase.com/docs/guides/queues/quickstart)
- [pgmq GitHub Repository](https://github.com/pgmq/pgmq)
- [Build Queue Worker Tutorial](https://dev.to/suciptoid/build-queue-worker-using-supabase-cron-queue-and-edge-function-19di)
- [pg_cron Debugging Guide](https://supabase.com/docs/guides/troubleshooting/pgcron-debugging-guide-n1KTaz)
- [Database Migrations Guide](https://supabase.com/docs/guides/deployment/database-migrations)
