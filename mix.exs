defmodule Alods.Mixfile do
  use Mix.Project

  def project do
    [
      app: :alods,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: true,
        ignore_warnings: ".dialyzer_ignore",
        flags: [
          :error_handling,
          :race_conditions,
          :unknown,
          :unmatched_returns,
        ],
      ],
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        "coveralls": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "vcr": :test,
        "vcr.delete": :test,
        "vcr.check": :test,
        "vcr.show": :test
      ],
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Alods.Supervisor, []}
    ]
  end

  defp deps do
    [
      {:cortex, ">= 0.0.0", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev]},
      {:dialyxir, ">= 0.0.0", only: [:dev]},
      {:ecto, ">= 0.0.0"},
      {:ex2ms, ">= 0.0.0"},
      {:excoveralls, ">= 0.0.0", only: [:test]},
      {:ex_doc, ">= 0.0.0", only: [:dev]},
      {:gen_stage, ">= 0.0.0"},
      {:httpoison, ">= 0.0.0"},
      {:poison, ">= 0.0.0"},
      {:exvcr, ">= 0.0.0", only: [:test]},
    ]
  end
end
