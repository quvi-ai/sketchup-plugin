require "sketchup"
require "extensions"

module QUVIAI
  PLUGIN_ROOT = File.dirname(__FILE__)

  extension = SketchupExtension.new("QUVIAI", File.join(PLUGIN_ROOT, "quviai_sketchup", "extension"))
  extension.version     = "1.0.0"
  extension.copyright   = "© 2025 QUVIAI"
  extension.creator     = "QUVIAI"
  extension.description = "AI-powered architectural render and 3D object generation for SketchUp"

  Sketchup.register_extension(extension, true)
end
