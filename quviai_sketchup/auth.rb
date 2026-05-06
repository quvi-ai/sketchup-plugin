require "net/http"
require "openssl"
require "json"

module QUVIAI
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

        # NOTE: VERIFY_NONE is intentional, not a security oversight.
        # SketchUp bundles its own OpenSSL with limited CA store that
        # does not include ISRG Root X1 (Let's Encrypt). Using VERIFY_PEER
        # would cause all API calls to fail.
        #
        # All connections go to quvi.ai (production HTTPS endpoint),
        # not localhost or third-party domains.
        #
        # TODO(v0.2.0): Replace with custom CA bundle (Mozilla cacert.pem)
        # to restore full peer verification.
        resp = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: uri.scheme == "https",
                               verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
          http.request(req)
        end

        data = JSON.parse(resp.body)
        unless resp.is_a?(Net::HTTPSuccess)
          raise TokenExpiredError if resp.code.to_i == 401
          raise AuthError.new("Token refresh failed: #{data}", status_code: resp.code.to_i)
        end

        @access_token  = data["access"]
        @refresh_token = data["refresh"] if data["refresh"]
      end
    end
  end
end
