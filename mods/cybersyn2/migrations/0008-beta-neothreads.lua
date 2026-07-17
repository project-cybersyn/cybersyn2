local scheduler = require("lib.core.scheduler")

-- Create new dispatch queue var
storage.dispatch_queue = {}

-- Kill all legacy threads implicitly
storage._thread = storage._thread or {}
storage._thread.threads = {}
storage._thread.buckets = { {} }
storage._thread.bucket_workloads = { 0 }
storage._thread.current_bucket = 1
storage._thread.wake_at = {}

-- Start new threads
scheduler.call_global_at(game.tick + 1, { "cs2", "restart_threads" })
