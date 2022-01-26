# PhoenixReverseProxy

**Share a port between many Phoenix apps in an umbrella**

## Setup
This Library provides everything you need to route requests and websockets
from one proxy app into your umbrella. This allows you to have multiple phoenix
applications in the same umbrella sharing the same port number.

Start by creating a Phoenix application in your umbrella `apps` folder:
  ```bash
  (cd apps && mix phx.new --no-webpack --no-ecto --no-html --no-gettext --no-dashboard reverse_proxy)
  # Optionally you can delete unused files
  rm -rf apps/reverse_proxy/lib/reverse_proxy_web/{channels,controllers,views}
  ```

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `phoenix_reverse_proxy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_reverse_proxy, "~> 1.0.0"}
  ]
end
```

In `apps/reverse_proxy/lib/reverse_proxy_web/endpoint.ex` replace the contents with
this and replace the default endpoint and add appropriate endpoints:
  ```elixir
  defmodule ReverseProxyWeb.Endpoint do
    use PhoenixReverseProxy, otp_app: :reverse_proxy

    # IMPORTANT: All of these macros except for proxy_default/1
    #            can take a path prefix so they all have an arity
    #            of 2 and 3.

    # Maps to http(s)://api.example.com/v1
    proxy("api.example.com", "v1", ExampleApiV1.Endpoint)

    # Maps to http(s)://api.example.com/v2
    proxy("api.example.com", "v2", ExampleApiV2.Endpoint)

    # Matches the domain only and no subdomains
    proxy("example.com", ExampleWeb.Endpoint)
    # Matched any subdomain such as http(s)://images.example.com/
    # but not the domain itself http(s)://example.com/
    proxy_subdomains("example.com", ExampleSubs.Endpoint)

    # Matches all subdomains and the domain itself.
    # This is equivalent to combining these rules:
    #   proxy("foofoovalve.com", FoofooValve.Endpoint)
    #   proxy_subdomains("foofoovalve.com", FoofooValve.Endpoint)
    proxy_all("foofoovalve.com", FoofooValve.Endpoint)

    # Matches anything not matched above
    proxy_default(ExampleWeb.Endpoint)
  end
  ```

In your config you must disable your other Phoenix applications from
listening on TCP ports. In your current endpoint configuration make the
following modifications.

  ```elixir
  # Configures the endpoint
  config :example_web, ExampleWeb.Endpoint,
    # Add this
    server: false,
    # Remove this and add it to the proxy endpoint configuration
    http: [port: System.get_env("PHX_PORT") || 4000],
    ...
  ```

Move contents of the files `apps/reverse_proxy/config/*.exs` to the
corresponding `config/*.exs` config files.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/phoenix_reverse_proxy](https://hexdocs.pm/phoenix_reverse_proxy).

