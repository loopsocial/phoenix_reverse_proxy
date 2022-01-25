defmodule PhoenixReverseProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_reverse_proxy,
      version: "1.0.1",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PhoenixReverseProxy",
      docs: [
        main: "PhoenixReverseProxy",
        extras: ["README.md"]
      ]
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
