require "base64"
require "tmpdir"

module QuviAI
  module Capture
    TARGET_LONG_EDGE = 1920
    MAX_LONG_EDGE    = 2048

    # Capture the active SketchUp viewport and return a base64-encoded JPEG string.
    # Must be called from the main thread.
    def self.viewport_to_base64
      tmp_path = File.join(Dir.tmpdir, "quviai_upload.jpg")

      view = Sketchup.active_model.active_view
      vw   = view.vpwidth
      vh   = view.vpheight

      # Scale to TARGET_LONG_EDGE maintaining aspect ratio
      if vw >= vh
        cap_w = TARGET_LONG_EDGE
        cap_h = [(vh * TARGET_LONG_EDGE / vw.to_f).round, 1].max
      else
        cap_h = TARGET_LONG_EDGE
        cap_w = [(vw * TARGET_LONG_EDGE / vh.to_f).round, 1].max
      end

      view.write_image(
        filename:    tmp_path,
        width:       cap_w,
        height:      cap_h,
        antialias:   true,
        transparent: false,
      )

      data = File.binread(tmp_path)
      Base64.strict_encode64(data)
    ensure
      File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
    end

    # Load raw image bytes from a file path and return base64-encoded JPEG/PNG.
    # Resizes to MAX_LONG_EDGE if larger.
    def self.file_to_base64(filepath)
      raise ArgumentError, "File not found: #{filepath}" unless File.exist?(filepath)

      # Load via SketchUp's image representation isn't available outside 3D context,
      # so we send the raw bytes and let the API handle it.
      data = File.binread(filepath)
      Base64.strict_encode64(data)
    end
  end
end
