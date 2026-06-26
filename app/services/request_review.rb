class RequestReview
  def initialize(work:, target:, user:)
    @work = work
    @target = target
    @user = user
  end

  def call
    payload = build_payload

    response =
      Faraday.post(@target.inbox_url) do |req|
        req.headers['Content-Type'] = 'application/ld+json'
        req.body = payload.to_json
      end

    save_log(payload, response)
  end

  private

  attr_reader :work, :target, :user

  def save_log(payload, response)
    depositor = User.find_by(email: work.depositor)
    recipient = [user, depositor].uniq

    work_link = ActionController::Base.helpers.link_to(work.id.to_s, work_url, target: '_blank', rel: 'noopener noreferrer')
    subject = I18n.t("request_review_notification.subject")
    if response.success?
      message = I18n.t("request_review_notification.success_body", work_link: work_link, response_body: response.body)
    else
      message = I18n.t("request_review_notification.failure_body", work_link: work_link, response_body: response.body)
    end

    Hyrax::MessengerService.deliver(user, recipient, message, subject)
  end

  def build_payload
    {
      "@context": [
        "https://www.w3.org/ns/activitystreams",
        "https://coar-notify.net"
      ],
      "id": "urn:uuid:#{work.id.to_s}",
      "actor": {
        "id": "mailto:#{user.email}",
        "name": user.display_name,
        "type": "Person"
      },
      "object": {
        "id": work_url,
        "ietf:cite-as": work_doi,
        "ietf:item": ietf_item,
        "type": [
          "page",
          "sorg:AboutPage"
        ],
      },
      "origin": {
        "id": repository_url,
        "inbox": "#{CoarNotifyInboxConfig::BASE_URL}/coar_notify_inbox/notifications",
        "type": "Service"
      },
      "target": {
        "id": target.service_url,
        "inbox": target.inbox_url,
        "type": "Service"
      },
      "type": [
        "Offer",
        "coar-notify:ReviewAction"
      ]
    }
  end

  private

  def files_payload
    file_set = Hyrax.query_service
                    .find_members(resource: work)
                    .find(&:file_set?)

    {
      "id": "#{repository_url}/downloads/#{file_set.id}",

      "mediaType": file_set&.mime_type,

      "type": [
        "Article",
        "sorg:ScholarlyArticle"
      ]
    }
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

  def user_orcid
    user.orcid.presence
  end

  def ietf_item
    primary_file = Hyrax.query_service
                        .find_members(resource: work)
                        .select(&:file_set?).first

    return {} unless primary_file

    {
      id: download_url(primary_file),
      mediaType: primary_file.original_file&.mime_type,
      type: [
        'Article',
        'sorg:ScholarlyArticle'
      ]
    }
  end

  def download_url(file_set)
    "#{repository_url}/downloads/#{file_set.id}"
  end
end