module QUVIAI
  # Safely execute a block on SketchUp's main thread from a background thread.
  # SketchUp model operations and most UI calls must run on the main thread.
  #
  # IMPORTANT: Call MainThread.ensure_timer_running from the main thread once
  # (e.g. in Panel#show) before any background threads use MainThread.run.
  # UI.start_timer must be called from the main thread to work reliably.
  module MainThread
    @queue = Queue.new
    @timer = nil
    @mutex = Mutex.new

    # Must be called from the main thread (e.g. inside Panel#show).
    # Starts the repeating drain timer if it isn't already running.
    def self.ensure_timer_running
      @mutex.synchronize do
        @timer ||= UI.start_timer(0, true) { drain }
      end
    end

    def self.run(&block)
      @queue << block
      # Fallback: try to create the timer from here too (works if already on
      # main thread; a no-op if ensure_timer_running was already called).
      @mutex.synchronize do
        @timer ||= UI.start_timer(0, true) { drain }
      end
    end

    def self.drain
      until @queue.empty?
        begin
          @queue.pop(true).call
        rescue ThreadError
          break
        rescue StandardError => e
          begin
            File.open(File.join(Dir.tmpdir, "quviai_errors.log"), "a") do |f|
              f.puts "[#{Time.now}] MainThread error: #{e.class}: #{e.message}"
            end
          rescue; end
        end
      end
    end
  end
end
