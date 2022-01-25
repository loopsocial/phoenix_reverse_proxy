defmodule PhoenixReverseProxyTest do
  use ExUnit.Case
  doctest PhoenixReverseProxy

  defmodule XWeb.Endpoint do
    use Phoenix.Endpoint, otp_app: :x

    socket("/socketX", XWeb.UserSocket,
      websocket: true,
      longpoll: false
    )
  end

  defmodule YWeb.Endpoint do
    use Phoenix.Endpoint, otp_app: :y

    socket("/socketY", YWeb.UserSocket,
      websocket: true,
      longpoll: false
    )
  end

  defmodule ZWeb.Endpoint do
    use Phoenix.Endpoint, otp_app: :z

    socket("/socketZ", ZWeb.UserSocket,
      websocket: true,
      longpoll: false
    )
  end

  test "combines sockets" do
    defmodule ReverseProxyWeb1.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy("y.com", YWeb.Endpoint)
      proxy("z.com", ZWeb.Endpoint)
      proxy_default(XWeb.Endpoint)
    end

    assert ReverseProxyWeb1.Endpoint.__sockets__() === [
             {"/socketY", YWeb.UserSocket, [websocket: true, longpoll: false]},
             {"/socketZ", ZWeb.UserSocket, [websocket: true, longpoll: false]},
             {"/socketX", XWeb.UserSocket, [websocket: true, longpoll: false]}
           ]
  end

  test "proxy ordered by specificity" do
    defmodule ReverseProxyWeb2.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy("y.com", YWeb.Endpoint)
      proxy("y.com", "v1", YWeb.Endpoint)
      proxy_default(XWeb.Endpoint)
    end

    defmodule ReverseProxyWeb3.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy_default(XWeb.Endpoint)
      proxy("y.com", "v1", YWeb.Endpoint)
      proxy("y.com", YWeb.Endpoint)
    end

    assert ReverseProxyWeb2.Endpoint.match_endpoint("y.com", ["v1"]) === YWeb.Endpoint
    assert ReverseProxyWeb3.Endpoint.match_endpoint("y.com", ["v1"]) === YWeb.Endpoint
  end

  test "proxy_subdomains proxies only subdomains" do
    defmodule ReverseProxyWeb4.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy_subdomains("test.com", YWeb.Endpoint)
      proxy_default(XWeb.Endpoint)
    end

    assert ReverseProxyWeb4.Endpoint.match_endpoint("foo.test.com", ["v1"]) === YWeb.Endpoint
    assert ReverseProxyWeb4.Endpoint.match_endpoint("test.com", ["v1"]) === XWeb.Endpoint
    assert ReverseProxyWeb4.Endpoint.match_endpoint("y.com", ["v1"]) === XWeb.Endpoint
  end

  test "proxy_all proxies the domain and the subdomains" do
    defmodule ReverseProxyWeb5.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy_all("test.com", YWeb.Endpoint)
      proxy_default(XWeb.Endpoint)
    end

    assert ReverseProxyWeb5.Endpoint.match_endpoint("foo.test.com", ["v1"]) === YWeb.Endpoint
    assert ReverseProxyWeb5.Endpoint.match_endpoint("test.com", ["v1"]) === YWeb.Endpoint
    assert ReverseProxyWeb5.Endpoint.match_endpoint("y.com", ["v1"]) === XWeb.Endpoint
  end

  test "proxy collision detection" do
    f = fn ->
      defmodule AWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :a

        socket("/socket", AWeb.UserSocket,
          websocket: true,
          longpoll: false
        )
      end

      defmodule BWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :b

        socket("/socket", BWeb.UserSocket,
          websocket: true,
          longpoll: false
        )
      end

      defmodule ReverseProxyWebAB.Endpoint do
        use PhoenixReverseProxy, otp_app: :abrp
        proxy_all("test.com", AWeb.Endpoint)
        proxy_default(BWeb.Endpoint)
      end
    end

    assert catch_error(f.()).message |> String.contains?("collision")
  end

  test "proxy_path proxies everything for a path" do
    defmodule ReverseProxyWeb6.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy_path("v1", YWeb.Endpoint)
      proxy_default(XWeb.Endpoint)
    end

    assert ReverseProxyWeb6.Endpoint.match_endpoint("blah.com", ["v1"]) === YWeb.Endpoint
  end

  test "proxy_path is applied after other rules except the default" do
    defmodule ReverseProxyWeb7.Endpoint do
      use PhoenixReverseProxy, otp_app: :rp
      proxy_path("v1", YWeb.Endpoint)
      proxy_all("foo.com", "v1", ZWeb.Endpoint)
      proxy_default(XWeb.Endpoint)
    end

    assert ReverseProxyWeb7.Endpoint.match_endpoint("foo.com", ["v1"]) === ZWeb.Endpoint
  end
end
