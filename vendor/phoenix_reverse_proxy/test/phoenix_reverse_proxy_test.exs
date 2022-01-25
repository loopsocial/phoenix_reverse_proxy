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
end
