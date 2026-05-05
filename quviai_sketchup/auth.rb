require "net/http"
require "json"

module QuviAI
  class JWTAuth
    attr_reader :access_token, :refresh_token, :client_key

    REFRESH_PATH = "/auth/jwt/refresh/".freeze

    def initialize(access_token:, refresh_token: nil, client_key: nil)
      @access_token  = access_token
      @refresh_token = refresh_token
      @client_key    = client_key
      @mutex         = Mutex.new
    end

    def headers
      h = {
        "Authorization" => "Bearer #{@access_token}",
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
      }
      h["X-API-Key"] = @client_key if @client_key
      h
    end

    def refresh!(base_url)
      raise AuthError, "No refresh token available" unless @refresh_token

      @mutex.synchronize do
        uri  = URI("#{base_url.chomp("/")}/auth/jwt/refresh/")
        body = JSON.generate({ refresh: @refresh_token })
        req  = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req["Accept"]       = "application/json"
        req.body            = body

        resp = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(req)
        end

        data = JSON.parse(resp.body)
        raise AuthError.new("Token refresh failed: #{data}", status_code: resp.code.to_i) unless resp.is_a?(Net::HTTPSuccess)

        @access_token  = data["access"]
        @refresh_token = data["refresh"] if data["refresh"]
      end
    end
  end
end
