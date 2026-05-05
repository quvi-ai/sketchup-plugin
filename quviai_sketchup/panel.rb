require "json"

module QUVIAI
  class Panel
    PANEL_W = 340
    PANEL_H = 620

    def initialize
      @dialog = UI::HtmlDialog.new(
        dialog_title:    "QUVIAI",
        preferences_key: "quviai_panel",
        width:           PANEL_W,
        height:          PANEL_H,
        min_width:       280,
        min_height:      400,
        resizable:       true,
      )
    end

    def show
      # Re-register callbacks and reload the file every time the panel is shown.
      # This ensures the sketchup JS bridge reflects current callbacks even after
      # the dialog was closed and reopened (some SketchUp versions drop them).
      register_callbacks
      @dialog.set_file(File.join(__dir__, "ui", "panel.html"))
      @dialog.show
      @dialog.bring_to_front
    end

    private

    def register_callbacks
      # Login — runs in a thread so the HTTP request does not block the main
      # thread, which would prevent execute_script from working.
      @dialog.add_action_callback("login") do |_ctx, email, password|
        Thread.new do
          begin
            credits = Extension.login(email, password)
            send_event("logged_in", { credits: credits })
          rescue StandardError => e
            send_event("error", { message: e.message })
          end
        end
      end

      # Google login — opens browser, starts local server to catch callback automatically
      @dialog.add_action_callback("start_google_login") do |_ctx|
        send_event("google_login_waiting", {})
        Extension.start_google_login do |result|
          if result[:error]
            send_event("error", { message: result[:error] })
          else
            send_event("logged_in", { credits: result[:credits] })
          end
        end
      end

      # Logout — local only, no HTTP, safe on main thread
      @dialog.add_action_callback("logout") do |_ctx|
        Extension.logout
        send_event("logged_out", {})
      end

      # Init — called by JS on page load; reads local storage only, no HTTP
      @dialog.add_action_callback("init") do |_ctx|
        if Extension.logged_in?
          send_event("logged_in", { credits: Store.credits })
        else
          send_event("logged_out", {})
        end
      end

      # Refresh credits — HTTP call, run in thread
      @dialog.add_action_callback("refresh_credits") do |_ctx|
        Thread.new do
          credits = Extension.refresh_credits
          send_event("credits_updated", { credits: credits })
        end
      end

      # Start render
      @dialog.add_action_callback("start_render") do |_ctx, params_json|
        params = JSON.parse(params_json, symbolize_names: true)
        params[:on_status] = method(:on_status_callback)
        send_event("render_started", {})
        Extension.start_render(params) do |result|
          if result[:error]
            send_event("render_error", { message: result[:error] })
          else
            MainThread.run do
              path    = Importer.open_image_temp(result[:image_bytes])
              credits = Extension.refresh_credits
              send_event("render_done", { path: path, credits: credits })
            end
          end
        end
      end

      # Save render result
      @dialog.add_action_callback("save_render") do |_ctx, path|
        begin
          data  = File.binread(path)
          saved = Importer.save_image(data)
          send_event("render_saved", { path: saved }) if saved
        rescue StandardError => e
          send_event("error", { message: e.message })
        end
      end

      # Start 3D object generation
      @dialog.add_action_callback("start_object") do |_ctx, params_json|
        params = JSON.parse(params_json, symbolize_names: true)
        params[:on_status] = method(:on_status_callback)
        send_event("object_started", {})
        Extension.start_object_generation(params) do |result|
          if result[:error]
            send_event("object_error", { message: result[:error] })
          else
            MainThread.run do
              begin
                Importer.import_glb(result[:glb_bytes])
                credits = Extension.refresh_credits
                send_event("object_done", { credits: credits })
              rescue StandardError => e
                send_event("object_error", { message: e.message })
              end
            end
          end
        end
      end
    end

    def on_status_callback(status)
      send_event("status_update", {
        status:   status.status,
        progress: status.progress_percentage || 0,
        eta:      status.eta_formatted,
      })
    end

    def send_event(name, payload = {})
      js = "window.quviReceive(#{JSON.generate({ event: name }.merge(payload))})"
      @dialog.execute_script(js)
    rescue StandardError
      # Dialog may have been closed
    end
  end
end
