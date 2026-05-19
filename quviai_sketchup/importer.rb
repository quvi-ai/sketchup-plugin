require "tmpdir"

module QUVIAI
  module Importer
    # Write GLB bytes to a temp file and import into the active SketchUp model.
    # Must be called from the main thread.
    def self.import_glb(glb_bytes, name: "quviai_object.glb")
      tmp_path = File.join(Dir.tmpdir, name)
      File.binwrite(tmp_path, glb_bytes)

      model = Sketchup.active_model
      model.start_operation("Import QUVIAI Object", true)
      begin
        status = model.import(tmp_path, false)
        if status
          model.commit_operation
        else
          model.abort_operation
          raise QuviError, "GLB import failed"
        end
        status
      rescue QuviError
        raise
      rescue => e
        model.abort_operation
        raise e
      end
    ensure
      File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
    end

    # Save raw image bytes to a user-chosen path and return that path.
    def self.save_image(image_bytes, suggested_name: "quviai_render.jpg")
      path = UI.savepanel("Save Render Result", "", suggested_name)
      return nil unless path

      File.binwrite(path, image_bytes)
      path
    end

    # Save image bytes to a temp file, open in OS viewer, return the path.
    # The temp file is intentionally kept so the user can save it via save_image.
    def self.open_image_temp(image_bytes, ext: "png")
      tmp_path = File.join(Dir.tmpdir, "quviai_result.#{ext}")
      File.binwrite(tmp_path, image_bytes)
      # Build a proper file:// URL for both Unix (/tmp/...) and Windows (C:\...)
      url = tmp_path.match?(/\A[A-Za-z]:/) \
        ? "file:///#{tmp_path.gsub("\\", "/")}" \
        : "file://#{tmp_path}"
      UI.openURL(url)
      tmp_path
    end
  end
end
