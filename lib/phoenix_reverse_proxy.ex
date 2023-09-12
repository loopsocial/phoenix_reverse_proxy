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

    # IMPORTANT: All of these macros except for proxy_default/1
    #            can take a path prefix so they all have an arity
    #            of 2 and 3.

    # Maps to http(s)://api.example.com/v1
    # proxy("api.example.com", "v1", ExampleApiV1.Endpoint)

    # Maps to http(s)://api.example.com/v2
    # proxy("api.example.com", "v2", ExampleApiV2.Endpoint)

    # Matches the domain only and no subdomains
    # proxy("example.com", ExampleWeb.Endpoint)
    # Matched any subdomain such as http(s)://images.example.com/
    # but not the domain itself http(s)://example.com/
    # proxy_subdomains("example.com", ExampleSubs.Endpoint)

    # Matches all subdomains and the domain itself.
    # This is equivalent to combining these rules:
    #   proxy("foofoovalve.com", FoofooValve.Endpoint)
    #   proxy_subdomains("foofoovalve.com", FoofooValve.Endpoint)
    # proxy_all("foofoovalve.com", FoofooValve.Endpoint)

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


  """

  defmacro __using__(opts) do
    # `:generate` silences some warnings from `init/1` and `call/2` redefinition of `Plug.Conn`
    quote [{:location, :keep}, :generated] do
      Module.register_attribute(__MODULE__, :reverse_proxy_routes, accumulate: true)
      Module.register_attribute(__MODULE__, :default_reverse_proxy_endpoint, accumulate: false)
      @before_compile unquote(PhoenixReverseProxy)

      @impl Plug
      def init(opts) when opts !== false do
        opts
      end

      @impl Plug
      def call(conn, opts) when opts !== false do
        matching_endpoint = match_endpoint(conn.host, conn.path_info)
        matching_endpoint.call(conn, matching_endpoint.init(opts))
      end

      import unquote(PhoenixReverseProxy)
      use Phoenix.Endpoint, unquote(opts)
    end
  end

  @doc ~S"""
  Reverse a domain name string (ASCII). This is used internally for pattern
  matching of subdomains.

  ## Examples
      iex> PhoenixReverseProxy.reverse_domain("abc.com")
      "moc.cba"
  """
  def reverse_domain(domain) do
    domain |> :binary.decode_unsigned(:little) |> :binary.encode_unsigned(:big)
  end

  @doc ~S"""
  Sets the default Phoenix endpoint to send requests to if we cannot match against anything.

  ## Examples
  ```
  proxy_default(ExampleWeb.Endpoint)
  ```
  """
  defmacro proxy_default(endpoint) do
    quote do
      @default_reverse_proxy_endpoint unquote(endpoint)
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a set of subdomains excluding the domain itself.
  Note that more specific matches are matched first regardless of the order in
  which they are specified.

  ## Examples
  ```
  proxy_subdomains("example.com", ExampleWeb.Endpoint)
  ```
  """
  defmacro proxy_subdomains(hostname, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        :_,
        :include_subdomains
      }
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a set of subdomains excluding the domain
  itself as well as a prefix of the path. Note that more specific
  matches are matched first regardless of the order in which they are
  specified.

  ## Examples
  ```
  proxy_subdomains("example.com", "v1/oauth", OAuthWebV1.Endpoint)
  ```
  """
  defmacro proxy_subdomains(hostname, path_prefix, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        unquote(path_prefix),
        :include_subdomains
      }
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a set of subdomains including the domain
  itself as well as a prefix of the path. Note that more specific
  matches are matched first regardless of the order in which they are
  specified.

  ## Examples
  ```
  proxy_all("example.com", "v1/oauth", OAuthWebV1.Endpoint)
  # Which is equivalent to:
  proxy("example.com", "v1/oauth", OAuthWebV1.Endpoint)
  proxy_subdomains("example.com", "v1/oauth", OAuthWebV1.Endpoint)
  ```
  """
  defmacro proxy_all(hostname, path_prefix, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        unquote(path_prefix),
        :_
      }
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        unquote(path_prefix),
        :include_subdomains
      }
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a set of subdomains including the domain itself.
  Note that more specific matches are matched first regardless of the order in
  which they are specified.

  ## Examples
  ```
  proxy_all("example.com", OAuthWeb.Endpoint)
  # Which is equivalent to:
  proxy("example.com", OAuthWeb.Endpoint)
  proxy_subdomains("example.com", OAuthWeb.Endpoint)
  ```
  """
  defmacro proxy_all(hostname, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        :_,
        :_
      }

      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        :_,
        :include_subdomains
      }
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a specific hostname. Note that more specific
  matches are matched first regardless of the order in which they are specified.

  ## Examples
  ```
  proxy("example.com", ExampleWeb.Endpoint)
  proxy("example.com", "v1/oauth", OAuthWebV1.Endpoint) # This matches first
  ```
  """
  defmacro proxy(hostname, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        :_,
        :_
      }
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a specific hostname and a prefix of the path.
  Note that more specific matches are matched first regardless of the order in which
  they are specified.

  ## Examples
  ```
  proxy("example.com", ExampleWeb.Endpoint)
  # For http(s)://example.com/oauth
  proxy("example.com", "v1/oauth", OAuthWebV1.Endpoint) # This matches first
  ```
  """
  defmacro proxy(hostname, path_prefix, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        unquote(hostname),
        unquote(path_prefix),
        :_
      }
    end
  end

  @doc ~S"""
  Sets the Phoenix endpoint for a specific a prefix of a path.
  Note that more specific matches are matched first regardless of the order in which
  they are specified.

  ## Examples
  ```
  proxy_path("v1/auth", AuthWebV1.Endpoint)
  """
  defmacro proxy_path(path_prefix, endpoint) do
    quote do
      @reverse_proxy_routes {
        unquote(endpoint),
        :_,
        unquote(path_prefix),
        :all_domains
      }
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

    to_bin = fn
      b when is_binary(b) -> b
      _ -> ""
    end

    sorted_routes_by_domain =
      Enum.to_list(routes_by_domain)
      |> Enum.sort_by(&(elem(&1, 0) |> to_bin.() |> byte_size()), :desc)

    # Generate our match_endpoint function
    dispatches =
      for {_domain, routes} <- sorted_routes_by_domain do
        for {endpoint, domain, path_prefix, :_} <- routes, is_binary(path_prefix) do
          quote [{:location, :keep}, :generated] do
            defp match_endpoint_int(unquote(domain |> reverse_domain()), [
                   unquote_splicing(String.split(path_prefix, "/", trim: true)) | _
                 ]) do
              unquote(endpoint)
            end
          end
        end
      end ++
        for {_domain, routes} <- sorted_routes_by_domain do
          for {endpoint, domain, :_, :_} <- routes do
            quote [{:location, :keep}, :generated] do
              defp match_endpoint_int(unquote(domain |> reverse_domain()), _) do
                unquote(endpoint)
              end
            end
          end
        end ++
        for {_domain, routes} <- sorted_routes_by_domain do
          for {endpoint, domain, path_prefix, :include_subdomains} <- routes,
              is_binary(path_prefix) do
            quote [{:location, :keep}, :generated] do
              defp match_endpoint_int(unquote(domain |> reverse_domain()) <> "." <> _, [
                     unquote_splicing(String.split(path_prefix, "/", trim: true)) | _
                   ]) do
                unquote(endpoint)
              end
            end
          end
        end ++
        for {_domain, routes} <- sorted_routes_by_domain do
          for {endpoint, domain, :_, :include_subdomains} <- routes do
            quote [{:location, :keep}, :generated] do
              defp match_endpoint_int(unquote(domain |> reverse_domain()) <> "." <> _, _) do
                unquote(endpoint)
              end
            end
          end
        end ++
        for {_domain, routes} <- sorted_routes_by_domain do
          for {endpoint, :_, path_prefix, :all_domains} <- routes do
            quote [{:location, :keep}, :generated] do
              defp match_endpoint_int(_, [
                     unquote_splicing(String.split(path_prefix, "/", trim: true)) | _
                   ]) do
                unquote(endpoint)
              end
            end
          end
        end ++
        [
          quote [{:location, :keep}, :generated] do
            defp match_endpoint_int(_, _) do
              unquote(default_reverse_proxy_endpoint)
            end
          end
        ]

    quote [{:location, :keep}, :generated] do
      duplicated_sockets =
        for endpoint <- unquote(endpoints) do
          for phoenix_socket <- endpoint.__sockets__() do
            Module.put_attribute(unquote(env.module), :phoenix_sockets, phoenix_socket)
            {phoenix_socket, endpoint}
          end
        end
        |> List.flatten()
        |> Enum.group_by(&(&1 |> elem(0) |> elem(0)))
        |> Enum.filter(&(&1 |> elem(1) |> length() > 1))

      for {path, duplicate_sockets} <- duplicated_sockets do
        endpoints_with_duplicate = duplicate_sockets |> Enum.map(&(&1 |> elem(1)))

        raise(
          "Socket path collision for path '#{path}' detected in endpoints #{inspect(endpoints_with_duplicate)}. " <>
            "Please change the paths to make them unique!"
        )
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

      unquote(dispatches)

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
      def match_endpoint(domain, path_info) do
        match_endpoint_int(PhoenixReverseProxy.reverse_domain(domain), path_info)
      end
    end
  end
end
