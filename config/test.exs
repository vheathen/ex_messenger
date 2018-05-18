use Mix.Config

# Defaults
config :ex_messenger, sms_adapter: ExMessenger.Json,

  poll_interval: 2_000, # an inteval between new messages check for batch sending
  status_check_interval: 2_000, # an interval between sent messages status check
  cleanup_interval: 2_000, # an interval between clean up
  
  send_timeout: 120_000, # timeout before failing 
  max_age: 300_000, # max time to keep sms
  
  push: true,    # push status updates to the sender by default
  auth: []

  config :ex_messenger, ExMessenger.Json, 
    api_base: "http://api.smsbliss.net/messages/v2/",
    request_billing_on_send: true # should it request billing details on each send message\messages?

# Do not start Manager on tests
config :ex_messenger, :children, []

# We need to test requests without real external service usage
config :tesla, adapter: :mock

# Logger: we don't need debug
config :logger, level: :info