use Mix.Config

config :alods,
       start_producers_and_consumers: true,
       consumer_amount: 10,
       check_for_work_delay_in_ms: 100
