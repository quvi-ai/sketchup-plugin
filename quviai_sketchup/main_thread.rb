module QUVIAI
  # Safely execute a block on SketchUp's main thread from a background thread.
  # SketchUp model operations and most UI calls must run on the main thread.
  # Usage: MainThread.run { Sketchup.active_model.import(...) }
  module MainThread
    @queue = Queue.new
    @timer = nil
    @mutex = Mutex.new

    def self.run(&block)
      @queue << block
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
          # Log but don't crash the timer
          puts "[QUVIAI] MainThread error: #{e.message}"
        end
      end
    end
  end
end
