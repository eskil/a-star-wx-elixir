import Config

config :astarwx,
  fps: 30

config :logger,
  :console,
  level: :debug,
  format: "[$level] $message $metadata\n",
  metadata: [:error_code, :file, :line]
