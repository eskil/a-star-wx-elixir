defmodule AstarWx.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarwx,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Docs
      name: "AstarWx",
      source_url: "https://github.com/eskil/a-star-wx-elixir",
      homepage_url: "https://github.com/eskil/a-star-wx-elixir",
      docs: [
        main: "Quickstart",
        extras: ["doc/Quickstart.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx],
      mod: {AstarWx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 5.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
    ]
  end
end
