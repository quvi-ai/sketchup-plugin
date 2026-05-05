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
      @html = File.read(File.join(__dir__, "ui", "panel.html"), encoding: "UTF-8")
    end

    def show
      # Pre-start the drain timer on the main thread so background threads
      # can safely queue events via MainThread.run.
      MainThread.ensure_timer_running
      register_callbacks
      @dialog.show
      @dialog.bring_to_front
      # Defer set_html by one event-loop tick so SketchUp's webview is fully
      # initialised before content is injected (blank-screen fix on first open).
      UI.start_timer(0.0, false) { @dialog.set_html(@html) }
    end

    private

    # -----------------------------------------------------------------------
    # Callbacks — add_action_callback blocks run on SketchUp's main thread.
    # -----------------------------------------------------------------------

    def register_callbacks
      # Email / password login.
      # Runs synchronously on the main thread (same as Blender plugin).
      # Brief UI freeze (~1 s) is acceptable; avoids all threading complexity.
      @dialog.add_action_callback("login") do |_ctx, email, password|
        begin
          credits = Extension.login(email, password)
          send_event("logged_in", { credits: credits })
        rescue StandardError => e
          send_event("error", { message: e.message })
        end
      end

      # Google OAuth — must be async (waits up to 120 s for browser redirect).
      @dialog.add_action_callback("start_google_login") do |_ctx|
        send_event("google_login_waiting", {})
        Extension.start_google_login do |result|
          # Callback arrives from the background OAuth thread.
          if result[:error]
            MainThread.run { send_event("error", { message: result[:error] }) }
          else
            MainThread.run { send_event("logged_in", { credits: result[:credits] }) }
          end
        end
      end

      @dialog.add_action_callback("logout") do |_ctx|
        Extension.logout
        send_event("logged_out", {})
      end

      # Called by JS once the page finishes loading — restores login state.
      @dialog.add_action_callback("init") do |_ctx|
        if Extension.logged_in?
          send_event("logged_in", { credits: Store.credits })
        else
          send_event("logged_out", {})
        end
      end

      # Credit refresh — synchronous on main thread (quick GET, acceptable freeze).
      @dialog.add_action_callback("refresh_credits") do |_ctx|
        credits = Extension.refresh_credits
        send_event("credits_updated", { credits: credits })
      end

      # Open pricing page in the system browser.
      @dialog.add_action_callback("open_pricing") do |_ctx|
        UI.openURL("https://quvi.ai/pricing")
      end

      # Render 3D — long-running, must be async.
      @dialog.add_action_callback("start_render") do |_ctx, params_json|
        params = JSON.parse(params_json, symbolize_names: true)
        params[:on_status] = method(:on_render_status)
        send_event("render_started", {})
        Extension.start_render(params) do |result|
          if result[:error]
            MainThread.run { send_event("render_error", { message: result[:error] }) }
          else
            MainThread.run do
              path    = Importer.open_image_temp(result[:image_bytes])
              credits = result[:last_credit] || Extension.refresh_credits
              Store.save_credits(credits) if credits
              send_event("render_done", { path: path, credits: credits.to_i })
            end
          end
        end
      end

      # Save last render result to a user-chosen file.
      @dialog.add_action_callback("save_render") do |_ctx, path|
        begin
          saved = Importer.save_image(File.binread(path))
          send_event("render_saved", { path: saved }) if saved
        rescue StandardError => e
          send_event("error", { message: e.message })
        end
      end

      # 3D Object generation — long-running, must be async.
      @dialog.add_action_callback("start_object") do |_ctx, params_json|
        params = JSON.parse(params_json, symbolize_names: true)
        params[:on_status] = method(:on_object_status)
        send_event("object_started", {})
        Extension.start_object_generation(params) do |result|
          if result[:error]
            MainThread.run { send_event("object_error", { message: result[:error] }) }
          else
            MainThread.run do
              begin
                Importer.import_glb(result[:glb_bytes])
                credits = result[:last_credit] || Extension.refresh_credits
                Store.save_credits(credits) if credits
                send_event("object_done", { credits: credits.to_i })
              rescue StandardError => e
                send_event("object_error", { message: e.message })
              end
            end
          end
        end
      end
    end

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    # Separate polling callbacks so render and object never overwrite each other.
    def on_render_status(status)
      MainThread.run do
        send_event("render_status_update", {
          status:   status.status,
          progress: status.progress_percentage || 0,
          eta:      status.eta_formatted,
        })
      end
    end

    def on_object_status(status)
      MainThread.run do
        send_event("object_status_update", {
          status:   status.status,
          progress: status.progress_percentage || 0,
          eta:      status.eta_formatted,
        })
      end
    end

    # execute_script is safe on the main thread and from callbacks.
    # Background-thread callers must go through MainThread.run first.
    def send_event(name, payload = {})
      js = "window.quviReceive(#{JSON.generate({ event: name }.merge(payload))})"
      @dialog.execute_script(js)
    rescue StandardError
      # Dialog may have been closed — ignore.
    end
  end
end
