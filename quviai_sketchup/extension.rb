require "sketchup"

require_relative "exceptions"
require_relative "models"
require_relative "auth"
require_relative "http"
require_relative "polling"
require_relative "client"
require_relative "store"
require_relative "capture"
require_relative "importer"
require_relative "panel"

module QuviAI
  module Extension
    @client    = nil
    @panel     = nil

    # ------------------------------------------------------------------
    # Client lifecycle
    # ------------------------------------------------------------------

    def self.client
      return @client if @client

      access  = Store.access_token
      refresh = Store.refresh_token
      return nil unless access && !access.empty?

      @client = QuviClient.from_tokens(access_token: access, refresh_token: refresh)
    end

    def self.logged_in?
      !!client
    end

    def self.login(email, password)
      @client = QuviClient.login(email: email, password: password)
      Store.save_tokens(access: @client.access_token, refresh: @client.refresh_token)
      credits = @client.get_credits
      Store.save_credits(credits)
      credits
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

      image_b64 = if params[:use_viewport]
        Capture.viewport_to_base64
      elsif params[:image_path] && !params[:image_path].empty?
        Capture.file_to_base64(params[:image_path])
      end

      ref_b64 = if params[:ref_image_path] && !params[:ref_image_path].empty?
        Capture.file_to_base64(params[:ref_image_path])
      end

      c = client  # capture for thread
      Thread.new do
        begin
          result = c.render_3d(
            prompt:      params[:prompt]      || "",
            style:       params[:style]       || "no style",
            day_time:    params[:day_time],
            weather:     params[:weather],
            render_type: params[:render_type],
            image:       image_b64,
            ref_image:   ref_b64,
            on_status:   params[:on_status],
          )
          image_bytes = c.download_result(result)
          callback.call(image_bytes: image_bytes, error: nil)
        rescue StandardError => e
          callback.call(image_bytes: nil, error: e.message)
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
          callback.call(glb_bytes: glb_bytes, error: nil)
        rescue StandardError => e
          callback.call(glb_bytes: nil, error: e.message)
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

    # Called once when the extension loads
    def self.register_menu
      menu = UI.menu("Plugins").add_submenu("QUVIAI")
      menu.add_item("Open Panel") { show_panel }
    end
  end
end

QuviAI::Extension.register_menu
