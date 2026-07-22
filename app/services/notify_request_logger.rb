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
      status: status,
      notification_id: notification_id
    )
  end

  def self.create_or_update_requests_for_notification(notification)
    #tod create or update
    status = notification_status(notification)
    work_id = work_id_from(notification, status)
    return if work_id.blank?


    request = NotifyRequest.find_by(work_id: work_id)
    return unless request

    request.update(status: status)
    request
  end

  def self.work_id_from(notification, status)
    if status == "announce_endorsement" || status == "announce_review"
      identifier = notification["raw_payload"]["context"]["id"]
      extract_work_id(identifier)
    else
      identifier = notification["raw_payload"]["object"]["object"]["id"]
      extract_work_id(identifier)
    end
  end

  def self.extract_work_id(identifier)
    return unless identifier

    identifier = identifier.to_s
    return Regexp.last_match(1) if identifier =~ %r{/concern/[^/]+/([^/?#]+)}

    identifier
  end

  def self.notification_status(notification)
    notificatio_type = notification["raw_payload"]["type"]
    
    if notificatio_type.is_a?(Array)
      notificatio_type[1].include?("EndorsementAction") ? "announce_endorsement" : "announce_review"
    else
      notificatio_type.to_s.underscore
    end
  end
end