require "tmpdir"

module QUVIAI
  module Importer
    # Write GLB bytes to a temp file and import into the active SketchUp model.
    # Must be called from the main thread.
    def self.import_glb(glb_bytes, name: "quviai_object.glb")
      tmp_path = File.join(Dir.tmpdir, name)
      File.binwrite(tmp_path, glb_bytes)

      status = Sketchup.active_model.import(tmp_path, false)
      raise QuviError, "GLB import failed (status: #{status})" unless status

      status
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

    # Open an image in the default OS viewer after saving to a temp file.
    def self.open_image_temp(image_bytes, ext: "jpg")
      tmp_path = File.join(Dir.tmpdir, "quviai_result.#{ext}")
      File.binwrite(tmp_path, image_bytes)
      UI.openURL("file://#{tmp_path}")
      tmp_path
    end
  end
end
