require "net/http"
require "openssl"
require "uri"
require "json"
require "base64"

module QUVIAI
  BASE_URL = "https://quvi.ai".freeze

  SSL_OPTS = {
    use_ssl:     true,
    verify_mode: OpenSSL::SSL::VERIFY_PEER,
    ca_file:     CA_BUNDLE,
  }.freeze

  class HTTPClient
    def initialize(auth:, base_url: BASE_URL, timeout: 120)
      @auth     = auth
      @base_url = base_url.chomp("/")
      @timeout  = timeout
    end

    def post(path, body)
      request(:post, path, body: JSON.generate(body), extra_headers: { "Content-Type" => "application/json" })
    end

    def get(path)
      request(:get, path)
    end

    def get_bytes(url)
      uri = URI(url)
      opts = uri.scheme == "https" ? SSL_OPTS : {}
      Net::HTTP.start(uri.host, uri.port, **opts,
                      open_timeout: @timeout, read_timeout: @timeout) do |http|
        resp = http.get(uri.request_uri)
        raise QuviError, "Download failed: #{resp.code}" unless resp.is_a?(Net::HTTPSuccess)
        resp.body.force_encoding("BINARY")
      end
    end

    def download_authenticated(path)
      uri = URI("#{@base_url}#{path}")
      req = Net::HTTP::Get.new(uri)
      @auth.headers.each { |k, v| req[k] = v }
      opts = uri.scheme == "https" ? SSL_OPTS : {}
      Net::HTTP.start(uri.host, uri.port, **opts,
                      open_timeout: @timeout, read_timeout: @timeout) do |http|
        resp = http.request(req)
        raise QuviError, "Download failed: #{resp.code}" unless resp.is_a?(Net::HTTPSuccess)
        resp.body.force_encoding("BINARY")
      end
    end

    private

    def request(method, path, body: nil, extra_headers: {}, retry_on_401: true)
      uri = URI("#{@base_url}#{path}")
      req = build_request(method, uri, body, extra_headers)

      resp = execute(uri, req)

      if resp.code.to_i == 401 && retry_on_401 && @auth.refresh_token
        @auth.refresh!(@base_url)
        req = build_request(method, uri, body, extra_headers)
        resp = execute(uri, req)
      end

      parse(resp)
    end

    def build_request(method, uri, body, extra_headers)
      req_class = method == :post ? Net::HTTP::Post : Net::HTTP::Get
      req = req_class.new(uri)
      @auth.headers.each { |k, v| req[k] = v }
      extra_headers.each  { |k, v| req[k] = v }
      req.body = body if body
      req
    end

    def execute(uri, req)
      opts = uri.scheme == "https" ? SSL_OPTS : {}
      Net::HTTP.start(uri.host, uri.port, **opts,
                      open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(req)
      end
    end

    def parse(resp)
      case resp.code.to_i
      when 200..299
        resp.body.empty? ? {} : JSON.parse(resp.body)
      when 401
        raise TokenExpiredError
      when 404
        raise TaskNotFoundError
      else
        begin
          data   = JSON.parse(resp.body)
          detail = data["detail"] || data["error"] || resp.body
        rescue StandardError
          detail = resp.body
        end
        raise QuviError, "API error #{resp.code}: #{detail}"
      end
    end
  end
end
