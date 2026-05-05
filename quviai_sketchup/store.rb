module QUVIAI
  # Thin wrapper around SketchUp's persistent key-value store.
  # All keys are namespaced under "QUVIAI" so they never collide with other extensions.
  module Store
    NS = "QUVIAI".freeze

    def self.get(key, default = nil)
      Sketchup.read_default(NS, key.to_s, default)
    end

    def self.set(key, value)
      Sketchup.write_default(NS, key.to_s, value)
    end

    def self.delete(key)
      Sketchup.write_default(NS, key.to_s, nil)
    end

    def self.access_token  = get("access_token")
    def self.refresh_token = get("refresh_token")
    def self.credits       = get("credits", -1).to_i

    def self.save_tokens(access:, refresh: nil)
      set("access_token",  access)
      set("refresh_token", refresh) if refresh
    end

    def self.clear_tokens
      delete("access_token")
      delete("refresh_token")
    end

    def self.save_credits(value)
      set("credits", value.to_i)
    end
  end
end
