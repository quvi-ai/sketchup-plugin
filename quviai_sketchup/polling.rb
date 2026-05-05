module QuviAI
  MAX_NETWORK_RETRIES = 10

  class JobPoller
    def initialize(http_client:, interval: 2.0, timeout: 900.0, on_status: nil)
      @http       = http_client
      @interval   = interval
      @timeout    = timeout
      @on_status  = on_status
    end

    def poll(task_id)
      deadline        = Time.now + @timeout
      network_retries = 0

      while Time.now < deadline
        begin
          response        = @http.post("/api/check-queue-status/", { task_id: task_id })
          network_retries = 0
        rescue SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED,
               Errno::EPIPE, EOFError, Net::HTTPBadResponse,
               Timeout::Error => e
          network_retries += 1
          raise if network_retries > MAX_NETWORK_RETRIES
          sleep(@interval)
          next
        end

        status = parse_status(task_id, response)
        @on_status&.call(status)

        case status.status
        when "completed"
          return response["result"] || {}
        when "failed"
          raise TaskFailedError.new(
            response["error"] || "Task failed without a reason",
            task_id: task_id
          )
        end

        sleep(@interval)
      end

      raise TaskTimeoutError.new(task_id: task_id, timeout: @timeout.to_i)
    end

    private

    def parse_status(task_id, response)
      eta = response["eta"] || {}
      TaskStatus.new(
        task_id:             task_id,
        status:              response["status"] || "unknown",
        position:            response["position"] || 0,
        queue_position:      response["queue_position"] || 0,
        eta_seconds:         eta["eta_seconds"],
        eta_formatted:       eta["eta_formatted"],
        progress_percentage: eta["progress_percentage"],
      )
    end
  end
end
