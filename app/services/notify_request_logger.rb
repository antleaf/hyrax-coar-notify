class NotifyRequestLogger
  def self.duplicate_request?(work_id:, request_type:)
    NotifyRequest.where(work_id: work_id.to_s, request_type: request_type).exists?
  end

  def self.log_request!(work:, target:, user:, request_type:, status:, notification_id: nil)
    NotifyRequest.create!(
      work_id: work.id.to_s,
      notify_service_id: target.id,
      user: user,
      request_type: request_type,
      status: status
    )
  end

  def self.update_requests_for_notification(notification)
    work_id = work_id_from(notification)
    return if work_id.blank?

    status = notification_status(notification)

    request = NotifyRequest.find_by(work_id: work_id)
    return unless request

    request.update(
        status: status,
        notification_id: notification["raw_payload"]["id"],
      )
  end

  def self.work_id_from(notification)
    extract_work_id(notification["raw_payload"]["inReplyTo"])
  end

  def self.extract_work_id(identifier)
    return unless identifier

    identifier = identifier.to_s
    return Regexp.last_match(1) if identifier =~ %r{^urn:uuid:(.+)$}
    return Regexp.last_match(1) if identifier =~ %r{/concern/[^/]+/([^/?#]+)$}

    identifier
  end

  def self.notification_status(notification)
    notification["raw_payload"]["type"].underscore
  end
end