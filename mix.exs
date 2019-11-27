defmodule ClosedIntervals.MixProject do
  use Mix.Project

  def project do
    [
      app: :closed_intervals,
      version: "0.3.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/evnu/closed_intervals",
      dialyzer: [
        ignore_warnings: "dialyzer.ignore-warnings",
        list_unused_filters: true,
        plt_add_apps: [:ex_unit, :mix]
      ],
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:docception, "~> 0.3", only: [:test, :dev], runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end

  defp description do
    "Storing a set of closed intervals"
  end

  defp package do
    [
      name: "closed_intervals",
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/evnu/closed_intervals"},
      maintainers: ["evnu"]
    ]
  end
end
