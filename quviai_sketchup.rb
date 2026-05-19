require "sketchup"
require "extensions"

module QUVIAI
  PLUGIN_ROOT = File.dirname(__FILE__)

  extension = SketchupExtension.new("QUVIAI", File.join(PLUGIN_ROOT, "quviai_sketchup", "extension"))
  extension.version     = "0.1.1"
  extension.copyright   = "© 2025–2026 Quick Vision Studios"
  extension.creator     = "Quick Vision Studios"
  extension.description = "AI-powered architectural render and 3D object generation for SketchUp"

  Sketchup.register_extension(extension, true)
end
