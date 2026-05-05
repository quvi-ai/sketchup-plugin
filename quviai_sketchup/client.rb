require "json"
require "net/http"
require "openssl"
require "base64"

module QUVIAI
  class QuviClient
    attr_reader :access_token, :refresh_token, :last_credit

    def initialize(auth:, base_url: BASE_URL, timeout: 120, poll_interval: 2.0, poll_timeout: 900.0)
      @auth          = auth
      @http          = HTTPClient.new(auth: auth, base_url: base_url, timeout: timeout)
      @poll_interval = poll_interval
      @poll_timeout  = poll_timeout
      @last_credit   = nil
    end

    # ------------------------------------------------------------------
    # Constructors
    # ------------------------------------------------------------------

    def self.login(email:, password:, base_url: BASE_URL, client_key: nil, **kwargs)
      data = unauthenticated_post(
        "#{base_url.chomp("/")}/auth/jwt/create/",
        { email: email, password: password },
        client_key: client_key
      )
      auth = JWTAuth.new(access_token: data["access"], refresh_token: data["refresh"], client_key: client_key)
      new(auth: auth, base_url: base_url, **kwargs)
    end

    def self.from_tokens(access_token:, refresh_token: nil, base_url: BASE_URL, client_key: nil, **kwargs)
      auth = JWTAuth.new(access_token: access_token, refresh_token: refresh_token, client_key: client_key)
      new(auth: auth, base_url: base_url, **kwargs)
    end

    def self.login_with_google(auth_code:, redirect_uri:, client_type: "android", base_url: BASE_URL, client_key: nil, **kwargs)
      data = unauthenticated_post(
        "#{base_url.chomp("/")}/api/auth/google/native/",
        { code: auth_code, redirect_uri: redirect_uri, client_type: client_type },
        client_key: client_key
      )
      auth = JWTAuth.new(access_token: data["access"], refresh_token: data["refresh"], client_key: client_key)
      new(auth: auth, base_url: base_url, **kwargs)
    end

    def self.login_with_apple(identity_token: nil, authorization_code: nil, base_url: BASE_URL, client_key: nil, **kwargs)
      raise ArgumentError, "Provide either identity_token or authorization_code" unless identity_token || authorization_code
      body = {}
      body["identity_token"]     = identity_token     if identity_token
      body["authorization_code"] = authorization_code if authorization_code
      data = unauthenticated_post("#{base_url.chomp("/")}/api/auth/apple/native/", body, client_key: client_key)
      auth = JWTAuth.new(access_token: data["access"], refresh_token: data["refresh"], client_key: client_key)
      new(auth: auth, base_url: base_url, **kwargs)
    end

    def access_token  = @auth.access_token
    def refresh_token = @auth.refresh_token

    # ------------------------------------------------------------------
    # Generation endpoints
    # ------------------------------------------------------------------

    def render_3d(prompt:, style: "no style", day_time: nil, weather: nil, render_type: nil,
                  image: nil, ref_image: nil, on_status: nil)
      task_id = submit_render_3d(prompt: prompt, style: style, day_time: day_time,
                                  weather: weather, render_type: render_type,
                                  image: image, ref_image: ref_image)
      poll_task(task_id, on_status: on_status)
    end

    def submit_render_3d(prompt:, style: "no style", day_time: nil, weather: nil,
                         render_type: nil, image: nil, ref_image: nil)
      body = { prompt: prompt, style: style }
      body[:dayTime]    = day_time    if day_time
      body[:weather]    = weather     if weather
      body[:renderType] = render_type if render_type
      body[:image]      = encode(image)     if image
      body[:ref_image]  = encode(ref_image) if ref_image
      resp = @http.post("/api/render-td/", body)
      @last_credit = resp["credit"].to_i if resp["credit"]
      resp["task_id"]
    end

    def generate_object_3d(prompt: "", image: nil, on_status: nil)
      task_id   = submit_object_3d(prompt: prompt, image: image)
      poll_http = HTTPClient.new(auth: @auth, base_url: @http.instance_variable_get(:@base_url), timeout: 15)
      poller    = JobPoller.new(http_client: poll_http, interval: @poll_interval,
                                timeout: @poll_timeout, on_status: on_status)
      result    = poller.poll(task_id)

      url = result["url"] || result["result_url"] || result["download_url"] ||
            result["model_url"] || result["model"] || result["file"] || result["object"]

      if url && url.to_s.match?(/\Ahttps?:\/\//)
        return @http.get_bytes(url.to_s)
      end

      @http.download_authenticated("/api/3d-objects/download/?task_id=#{task_id}")
    end

    def submit_object_3d(prompt: "", image: nil)
      body = image ? { image: encode(image) } : { prompt: prompt }
      resp = @http.post("/api/td-object/", body)
      @last_credit = resp["credit"].to_i if resp["credit"]
      resp["task_id"]
    end

    def generate_canvas(image:, prompt: "", is_sketch: false, on_status: nil)
      task_id = submit_canvas(image: image, prompt: prompt, is_sketch: is_sketch)
      poll_task(task_id, on_status: on_status)
    end

    def submit_canvas(image:, prompt: "", is_sketch: false)
      body = { image: encode(image), prompt: prompt, isSketch: is_sketch ? 1 : 0 }
      resp = @http.post("/api/generate-canvas-react/", body)
      resp["task_id"]
    end

    def generate_image(prompt:, style: "no style", width: 1024, height: 1024, on_status: nil)
      task_id = submit_generate_image(prompt: prompt, style: style, width: width, height: height)
      poll_task(task_id, on_status: on_status)
    end

    def submit_generate_image(prompt:, style: "no style", width: 1024, height: 1024)
      resp = @http.post("/api/generate-image/", { prompt: prompt, style: style, width: width, height: height })
      resp["task_id"]
    end

    def remove_background(image:, on_status: nil)
      task_id = submit_remove_background(image: image)
      poll_task(task_id, on_status: on_status)
    end

    def submit_remove_background(image:)
      resp = @http.post("/api/remove-background/", { image: encode(image) })
      resp["task_id"]
    end

    # ------------------------------------------------------------------
    # Polling & user data
    # ------------------------------------------------------------------

    def poll_task(task_id, on_status: nil)
      poll_http = HTTPClient.new(auth: @auth, base_url: @http.instance_variable_get(:@base_url), timeout: 15)
      poller    = JobPoller.new(http_client: poll_http, interval: @poll_interval,
                                timeout: @poll_timeout, on_status: on_status)
      result    = poller.poll(task_id)
      parse_result(task_id, result)
    end

    def get_user_data
      @http.get("/api/user-data/")
    end

    def get_credits
      get_user_data["credit"].to_i
    rescue StandardError
      -1
    end

    def download_result(result)
      return result.image_data if result.image_data
      return @http.get_bytes(result.url) if result.url
      raise QuviError, "GenerateResult has neither image_data nor url"
    end

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    private

    def encode(image)
      return Base64.strict_encode64(image) if image.is_a?(String) && image.encoding == Encoding::BINARY
      return Base64.strict_encode64(image) if image.is_a?(String) && !image.start_with?("http") && File.file?(image)

      if image.is_a?(String) && File.file?(image)
        return Base64.strict_encode64(File.binread(image))
      end

      image.to_s
    end

    def parse_result(task_id, result)
      outputs = normalize_result(result)
      raise QuviError, "Task #{task_id} completed but result payload is empty" if outputs.empty?

      first = outputs.first
      if first.start_with?("http://", "https://", "//")
        GenerateResult.new(task_id: task_id, url: first)
      else
        GenerateResult.new(task_id: task_id, image_data: decode_base64(first))
      end
    end

    # Mirrors the Python SDK's normalize_result in quviai/utils.py exactly.
    # Handles list results, all known dict keys, and one level of nesting.
    def normalize_result(result)
      return [] unless result

      return result.select { |v| v.is_a?(String) && !v.empty? } if result.is_a?(Array)
      return [] unless result.is_a?(Hash)

      found = extract_strings(result)
      return found unless found.empty?

      nested = result["result"]
      nested.is_a?(Hash) ? extract_strings(nested) : []
    end

    def extract_strings(hash)
      %w[urls images image url file_url].each do |key|
        val = hash[key]
        if val.is_a?(Array)
          items = val.select { |v| v.is_a?(String) && !v.empty? }
          return items unless items.empty?
        end
        return [val] if val.is_a?(String) && !val.empty?
      end
      []
    end

    # Robust base64 decoder — handles URL-safe alphabet, data-URI prefix,
    # and incorrect padding (all variants seen in API responses).
    def decode_base64(b64)
      b64 = b64.sub(/\Adata:[^;]+;base64,/, "").strip
      b64 = b64.tr("-_", "+/")
      b64 = b64.gsub(/=+\z/, "")
      b64 += "=" * (-b64.length % 4)
      Base64.decode64(b64)
    end

    def self.unauthenticated_post(url, body, client_key: nil)
      uri  = URI(url)
      req  = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Accept"]       = "application/json"
      req["X-API-Key"]    = client_key if client_key
      req.body            = JSON.generate(body)

      resp = Net::HTTP.start(uri.host, uri.port,
                             use_ssl:     uri.scheme == "https",
                             verify_mode: OpenSSL::SSL::VERIFY_NONE,
                             open_timeout: 30, read_timeout: 120) do |http|
        http.request(req)
      end

      data = JSON.parse(resp.body)
      return data if resp.is_a?(Net::HTTPSuccess)

      detail = data["detail"] || data["error"] || (data["non_field_errors"] || []).first || "Login failed"
      raise LoginError.new(detail.to_s, status_code: resp.code.to_i)
    end
  end
end
