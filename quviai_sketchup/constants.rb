module QUVIAI
  # CLIENT_KEY: Public identifier used by backend to identify
  # the source of the request (SketchUp plugin). This is NOT a
  # secret credential. It only identifies the client type for
  # the QUVIAI backend's request routing.
  CLIENT_KEY        = "quvi_dev_NELiELVUdoN3ATPxaw3fPTjEgNDXNTF1".freeze
  GOOGLE_CLIENT_ID  = "200337983560-h4e25beo1p0vh56peq52qo1fd9tnoaom.apps.googleusercontent.com".freeze
  GOOGLE_OAUTH_PORT = 8765

  # Bundled Mozilla CA bundle for TLS peer verification.
  # SketchUp ships OpenSSL with an incomplete CA store (missing ISRG Root X1),
  # so we embed our own bundle and point ca_file here.
  CA_BUNDLE = File.join(__dir__, "vendor", "cacert.pem").freeze

  # Hosts from which the plugin is permitted to download binary content
  # (render images and 3D object files). All other hosts are rejected so
  # a compromised or buggy backend cannot redirect downloads elsewhere.
  ALLOWED_DOWNLOAD_HOSTS = [
    "quvi.ai",
    "www.quvi.ai",
    "quvi-server-storage.s3.amazonaws.com",
  ].freeze
end
