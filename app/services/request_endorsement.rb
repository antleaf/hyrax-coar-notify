# frozen_string_literal: true

class RequestEndorsement
  attr_reader :work, :target, :user

  PREFERRED_MIME_TYPES = [
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  ].freeze

  class MissingFileSetError < StandardError; end

  def initialize(work:, target:, user:)
    @work = work
    @target = target
    @user = user
  end

  def call
    request = build_request_endorsement
    validation_result = request.validate

    response = client.send(request, validate: validation_result)
    notify_success(response)
  rescue MissingFileSetError => e
    notify_failure(e.message)
  rescue Coarnotify::ValidationError => e
    notify_failure(format_validation_errors(e))
  rescue Coarnotify::NotifyException => e
    notify_failure(e.message)
  rescue StandardError => e
    notify_failure(e.message)
    raise
  end

  private

  def build_request_endorsement
    Coarnotify::Patterns::RequestEndorsement.new.tap do |request|
      request.actor = build_actor
      request.origin = build_origin
      request.target = build_target
      request.object = build_object
      request.in_reply_to = work_url
    end
  end

  def build_actor
    Coarnotify::Core::Notify::NotifyActor.new.tap do |actor|
      actor.id = "mailto:#{user.email}"
      actor.name = user.display_name
      actor.type = "Person"
    end
  end

  def build_origin
    Coarnotify::Core::Notify::NotifyService.new.tap do |origin|
      origin.id = repository_url
      origin.inbox = "#{CoarNotifyInboxConfig::BASE_URL}/coar_notify_inbox/notifications"
      origin.type = "Service"
    end
  end

  def build_target
    Coarnotify::Core::Notify::NotifyService.new.tap do |notify_target|
      notify_target.id = target.service_url
      notify_target.inbox = target.inbox_url
      notify_target.type = "Service"
    end
  end

  def build_object
    Coarnotify::Core::Notify::NotifyObject.new.tap do |object|
      object.id = work_url
      object.cite_as = work_doi if work_doi.present?
      object.item = ietf_item if ietf_item.present?
      object.type = [
        "Page",
        "sorg:AboutPage"
      ]
    end
  end

  def client
    @client ||= Coarnotify::Client::COARNotifyClient.new(
      inbox_url: target.inbox_url
    )
  end

  def notify_success(response)
    notify(
      I18n.t(
        "request_endorsement_notification.success_body",
        work_link: work_link,
        response_body: response.body
      )
    )
  end

  def notify_failure(message)
    notify(
      I18n.t(
        "request_endorsement_notification.failure_body",
        work_link: work_link,
        response_body: message
      )
    )
  end

  def notify(message)
    Hyrax::MessengerService.deliver(
      user,
      recipients,
      message,
      I18n.t("request_endorsement_notification.subject")
    )
  end

  def recipients
    @recipients ||= [user, User.find_by(email: work.depositor)].compact.uniq
  end

  def work_link
    @work_link ||= ActionController::Base.helpers.link_to(
      work.id.to_s,
      work_url,
      target: "_blank"
    )
  end

  def format_validation_errors(error)
    error.errors.map { |field, message| "#{field}: #{message}" }.join(", ")
  end

  def work_url
    "#{repository_url}/concern/#{work.class.to_s.underscore.pluralize}/#{work.id}"
  end

  def work_doi
    work.identifier&.first
  end

  def repository_url
    ENV.fetch("APPLICATION_URL")
  end

  def ietf_item
    return unless file_set

    Coarnotify::Core::Notify::NotifyItem.new.tap do |item|
      item.id = download_url(file_set)
      item.media_type = file_set.original_file&.mime_type
      item.type = [
        "Article",
        "sorg:ScholarlyArticle"
      ]
    end
  end

  def file_set
    @file_set ||= begin
      file_sets = Hyrax.query_service.find_members(resource: work).select(&:file_set?)

      file_set = file_sets.find do |fs|
        PREFERRED_MIME_TYPES.include?(fs.original_file&.mime_type)
      end || file_sets.first

      raise MissingFileSetError, I18n.t('request_endorsement_notification.fileset_missing') unless file_set

      file_set
    end
  end

  def download_url(file_set)
    "#{repository_url}/downloads/#{file_set.id}"
  end
end