-record(msg, {time, source, ps, content}).
-record(token, {id, channel_id, name, addon}).
-record(drain, {id, channel_id, host, port}).

-define(DEFAULT_LOG_HISTORY, 500).
-define(ADVANCED_LOG_HISTORY, 1500).

-define(BASIC_THROUGHPUT, 500).
-define(EXPANDED_THROUGHPUT, 10000).