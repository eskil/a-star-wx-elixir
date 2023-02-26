import Config

config :astarwx,
  fps: 30

config :logger,
  :console,
  level: :info,
  format: "[$level] $message $metadata\n\n",
  metadata: [:error_code, :file, :line]
