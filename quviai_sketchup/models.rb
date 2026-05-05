module QuviAI
  TaskStatus = Struct.new(
    :task_id,
    :status,
    :position,
    :queue_position,
    :eta_seconds,
    :eta_formatted,
    :progress_percentage,
    keyword_init: true
  )

  GenerateResult = Struct.new(:task_id, :url, :image_data, keyword_init: true)
end
