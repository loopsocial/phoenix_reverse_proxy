defmodule PhoenixReverseProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_reverse_proxy,
      version: "1.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PhoenixReverseProxy",
      docs: [
        main: "PhoenixReverseProxy",
        extras: ["README.md"]
      ],
      description:
        "PhoenixReverseProxy is a high-performance reverse proxy solution for Phoenix. Utilizing the BEAM and pattern matching, it routes requests efficiently and handles reverse domain matching and WebSockets seamlessly. The best solution for Phoenix web apps that require a reverse proxy.",
      package: %{
        licenses: ["Apache-2.0"],
        links: %{
          "GitHub" => "https://github.com/loopsocial/phoenix_reverse_proxy",
          "Hex" => "https://hex.pm/packages/phoenix_reverse_proxy"
        }
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:phoenix, "~> 1.5.3", only: :test, runtime: false}
    ]
  end
end
