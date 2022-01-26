defmodule PhoenixReverseProxy do
  @moduledoc """
  This Library provides everything you need to route requests and websockets
  from one proxy app into your umbrella. This allows you to have multiple phoenix
  applications in the same umbrella sharing the same port number.

  Start by creating a Phoenix application in your umbrella `apps` folder:
  ```bash
  (cd apps && mix phx.new --no-webpack --no-ecto --no-html --no-gettext --no-dashboard reverse_proxy)
  # Optionally you can delete unused files
  rm -rf apps/reverse_proxy/lib/reverse_proxy_web/{channels,controllers,views}
  ```

  In `apps/reverse_proxy/lib/reverse_proxy_web/endpoint.ex` replace the contents with
  this and replace the default endpoint and add appropriate endpoints:
  ```elixir
  defmodule ReverseProxyWeb.Endpoint do
    use PhoenixReverseProxy, otp_app: :reverse_proxy

    # Maps to http(s)://api.example.com/v1
    # proxy("api.example.com", "v1", ExampleApiV1.Endpoint)

    # Maps to http(s)://api.example.com/v2
    # proxy("api.example.com", "v2", ExampleApiV2.Endpoint)

    # proxy("example.com", ExampleWeb.Endpoint)

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


  """

  defmacro __using__(opts) do
    # `:generate` silences warnings from `init/1` and `call/2` redefinition of `Phoenix.Endpoint`
    quote [{:location, :keep}, :generated] do
      Module.register_attribute(__MODULE__, :reverse_proxy_routes, accumulate: true)
      Module.register_attribute(__MODULE__, :default_reverse_proxy_endpoint, accumulate: false)
      @before_compile unquote(PhoenixReverseProxy)

      def init(opts) when opts === opts do
        opts
      end

      def call(conn, opts) when opts === opts do
        matching_endpoint = match_endpoint(conn.host, conn.path_info)
        matching_endpoint.call(conn, matching_endpoint.init(opts))
      end

      use Phoenix.Endpoint, unquote(opts)
      import unquote(PhoenixReverseProxy)
    end
  end

  @doc ~S"""
  Sets the default Phoenix endpoint to send requests to if we cannot match against anything.
  """
  defmacro proxy_default(endpoint) do
    quote do
      @default_reverse_proxy_endpoint unquote(endpoint)
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a specific hostname. Note that more complete matches are
  matched first regardless of the order they are specified.

  ## Examples
    proxy("example.com", ExampleWeb.Endpoint)
    proxy("example.com", "oauth", OAuthWeb.Endpoint) # This matches first
  """
  defmacro proxy(hostname, endpoint) do
    quote do
      @reverse_proxy_routes {unquote(endpoint), unquote(hostname)}
    end
  end


  @doc ~S"""
  Sets the Phoenix endpoint for a specific hostname and first component of the path.
  Note that more complete matches are matched first regardless of the order they are specified.

  ## Examples
    proxy("example.com", ExampleWeb.Endpoint)
    # For http(s)://example.com/oauth
    proxy("example.com", "oauth", OAuthWeb.Endpoint) # This matches first
  """
  defmacro proxy(hostname, path_prefix, endpoint) do
    quote do
      @reverse_proxy_routes {unquote(endpoint), unquote(hostname), unquote(path_prefix)}
    end
  end

  # This must be done after other macros and before compilation because we use metaprogramming
  # variables from Phoenix.Endpoint.
  defmacro __before_compile__(env) do
    reverse_proxy_routes = Module.get_attribute(env.module, :reverse_proxy_routes)

    default_reverse_proxy_endpoint =
      Module.get_attribute(env.module, :default_reverse_proxy_endpoint)

    endpoints =
      [default_reverse_proxy_endpoint | reverse_proxy_routes |> Enum.map(&elem(&1, 0))]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    routes_by_domain = reverse_proxy_routes |> Enum.group_by(&elem(&1, 1))

    routes_by_domain =
      for {k, v} <- routes_by_domain, into: %{} do
        {k, Enum.reverse(v)}
      end

    # Generate our match_endpoint function
    dispatches =
      for {_domain, routes} <- routes_by_domain do
        for {endpoint, domain, path_prefix} <- routes do
          quote location: :keep do
            def match_endpoint(unquote(domain), [unquote(path_prefix) | _]) do
              unquote(endpoint)
            end
          end
        end
      end ++
      for {_domain, routes} <- routes_by_domain do
        for {endpoint, domain} <- routes do
          quote location: :keep do
            def match_endpoint(unquote(domain), _) do
              unquote(endpoint)
            end
          end
        end
      end ++
      [
        quote location: :keep do
          def match_endpoint(_, _) do
            unquote(default_reverse_proxy_endpoint)
          end
        end
      ]

    quote location: :keep do
      for endpoint <- unquote(endpoints) do
        for phoenix_socket <- endpoint.__sockets__() do
          Module.put_attribute(unquote(env.module), :phoenix_sockets, phoenix_socket)
        end
      end

      def __reverse_proxy_routes__() do
        @reverse_proxy_routes
      end

      def __default_proxy_route__() do
        @default_reverse_proxy_endpoint
      end

      def __all_proxy_endpoints__() do
        unquote(endpoints)
      end

      @spec match_endpoint(domain :: String.t(), path_info :: Plug.Conn.segments()) :: module()
      @doc ~S"""
        Pattern match on `domain` and `path_info` to decide what endpoint application
        should the request be routed to. For `path_info` only the first element is
        matched not the entire `path_path` value.

        ## Examples
          iex> ReverseProxyWeb.Endpoint.match_endpoint("example.com", ["version"])
          ExampleWeb.Endpoint

          iex> ReverseProxyWeb.Endpoint.match_endpoint("example.com", ["auth", "login"])
          ExampleWeb.Endpoint

      """
      unquote(dispatches)
    end
  end
end
