require "sketchup"
require "socket"
require "uri"

require_relative "constants"
require_relative "exceptions"
require_relative "models"
require_relative "auth"
require_relative "http"
require_relative "polling"
require_relative "client"
require_relative "store"
require_relative "capture"
require_relative "importer"
require_relative "main_thread"
require_relative "panel"

module QUVIAI
  module Extension
    @client        = nil
    @panel         = nil
    @google_server = nil

    # ------------------------------------------------------------------
    # Client lifecycle
    # ------------------------------------------------------------------

    def self.client
      return @client if @client

      access  = Store.access_token
      refresh = Store.refresh_token
      return nil unless access && !access.empty?

      @client = QuviClient.from_tokens(
        access_token:  access,
        refresh_token: refresh,
        client_key:    CLIENT_KEY,
      )
    end

    def self.logged_in?
      !!client
    end

    def self.login(email, password)
      @client = QuviClient.login(email: email, password: password, client_key: CLIENT_KEY)
      Store.save_tokens(access: @client.access_token, refresh: @client.refresh_token)
      # get_credits is a second HTTP call — make it non-fatal so a transient
      # network hiccup here doesn't break a login that already succeeded.
      credits = begin; @client.get_credits; rescue; -1; end
      Store.save_credits(credits)
      credits
    end

    # Opens Google OAuth in the system browser.
    # A local TCP server on SO_REUSEADDR catches the redirect so retries work immediately.
    def self.start_google_login(&callback)
      redirect_uri = "http://localhost:#{GOOGLE_OAUTH_PORT}"
      auth_url = "https://accounts.google.com/o/oauth2/v2/auth" \
                 "?client_id=#{URI.encode_www_form_component(GOOGLE_CLIENT_ID)}" \
                 "&redirect_uri=#{URI.encode_www_form_component(redirect_uri)}" \
                 "&response_type=code" \
                 "&scope=email%20profile" \
                 "&access_type=offline"

      Thread.new do
        server = nil
        begin
          # Tear down any leftover server from a previous attempt.
          begin; @google_server&.close; rescue; end
          @google_server = nil

          # SO_REUSEADDR lets us rebind immediately after the previous attempt
          # closed the socket, avoiding the Windows TIME_WAIT EADDRINUSE error.
          server = Socket.new(:INET, :STREAM)
          server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
          server.bind(Addrinfo.tcp("127.0.0.1", GOOGLE_OAUTH_PORT))
          server.listen(1)
          @google_server = server

          # Open the Google consent page in the user's default system browser.
          MainThread.run { UI.openURL(auth_url) }

          # Wait up to 120 s for the OAuth redirect.
          unless IO.select([server], nil, nil, 120)
            raise "Google login timed out. Please try again."
          end

          conn, _ = server.accept
          server.close
          @google_server = nil
          server = nil

          request = +""
          while (line = conn.gets)
            break if line =~ /^\r?\n$/
            request << line
          end

          code = request.match(/GET \/[^\s]*[?&]code=([^&\s]+)/i)&.captures&.first

          success_html = "<html><body style='font-family:sans-serif;text-align:center;padding-top:80px'>" \
                         "<h2 style='color:#2ecc71'>Login successful!</h2>" \
                         "<p>You can close this tab and return to SketchUp.</p></body></html>"
          failure_html = "<html><body style='font-family:sans-serif;text-align:center;padding-top:80px'>" \
                         "<h2 style='color:#e74c3c'>Login failed.</h2>" \
                         "<p>Please close this tab and try again in SketchUp.</p></body></html>"
          conn.print "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n" \
                     + (code ? success_html : failure_html)
          conn.close

          if code
            @client = QuviClient.login_with_google(
              auth_code:    code,
              redirect_uri: redirect_uri,
              client_type:  "android",
              client_key:   CLIENT_KEY,
            )
            Store.save_tokens(access: @client.access_token, refresh: @client.refresh_token)
            credits = begin; @client.get_credits; rescue; -1; end
            Store.save_credits(credits)
            callback.call(credits: credits, error: nil)
          else
            callback.call(credits: nil, error: "No authorisation code received from Google.")
          end
        rescue StandardError => e
          callback.call(credits: nil, error: e.message)
        ensure
          server&.close rescue nil
          @google_server = nil
        end
      end
    end

    def self.logout
      @client = nil
      Store.clear_tokens
    end

    def self.refresh_credits
      return -1 unless client
      credits = client.get_credits
      Store.save_credits(credits)
      credits
    rescue StandardError
      -1
    end

    # ------------------------------------------------------------------
    # Render 3D — runs in background thread, calls back on completion
    # ------------------------------------------------------------------

    def self.start_render(params, &callback)
      raise QuviError, "Not logged in" unless client

      # Always capture the current viewport at 1920px long edge (lossless PNG).
      # This call must happen on the main thread, which is where add_action_callback
      # blocks execute, so we capture here before handing off to the worker thread.
      image_b64 = Capture.viewport_to_base64

      c = client
      Thread.new do
        begin
          result = c.render_3d(
            prompt:      params[:prompt]      || "",
            style:       params[:style]       || "no style",
            day_time:    params[:day_time],
            weather:     params[:weather],
            render_type: params[:render_type],
            image:       image_b64,
            on_status:   params[:on_status],
          )
          image_bytes = c.download_result(result)
          callback.call(image_bytes: image_bytes, last_credit: c.last_credit, error: nil)
        rescue StandardError => e
          callback.call(image_bytes: nil, last_credit: nil, error: e.message)
        end
      end
    end

    # ------------------------------------------------------------------
    # 3D Object generation
    # ------------------------------------------------------------------

    def self.start_object_generation(params, &callback)
      raise QuviError, "Not logged in" unless client

      image_b64 = if params[:image_path] && !params[:image_path].empty?
        Capture.file_to_base64(params[:image_path])
      end

      c = client
      Thread.new do
        begin
          glb_bytes = c.generate_object_3d(
            prompt:    params[:prompt]   || "",
            image:     image_b64,
            on_status: params[:on_status],
          )
          callback.call(glb_bytes: glb_bytes, last_credit: c.last_credit, error: nil)
        rescue StandardError => e
          callback.call(glb_bytes: nil, last_credit: nil, error: e.message)
        end
      end
    end

    # ------------------------------------------------------------------
    # Panel
    # ------------------------------------------------------------------

    def self.show_panel
      @panel ||= Panel.new
      @panel.show
    end

    def self.register_menu
      menu = UI.menu("Plugins").add_submenu("QUVIAI")
      menu.add_item("Open Panel") { show_panel }
    end
  end
end

QUVIAI::Extension.register_menu
