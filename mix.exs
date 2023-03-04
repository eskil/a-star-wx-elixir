defmodule AstarWx.MixProject do
  use Mix.Project

  def project do
    [
      app: :astarwx,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
    ]
  end
end
