# frozen_string_literal: true

module Hyrax
  module CoarNotify
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

      REQUEST_TYPE = "request_endorsement".freeze

      def call
        return if duplicate_request?

        request_payload = build_payload.with_indifferent_access
        pretty_generated_payload = JSON.pretty_generate(request_payload.as_json)
        Rails.logger.info("COAR Notify Request Payload:\n#{pretty_generated_payload}")

        response = Faraday.post(target.inbox_url) do |req|
          req.headers['Content-Type'] = 'application/ld+json'
          req.headers['Authorization'] = "Bearer #{target.api_key}" if target.api_key.present?
          req.body = pretty_generated_payload
        end

        NotifyRequestLogger.log_request!(
          work: work,
          target: target,
          user: user,
          request_type: request_type,
          status: "sent",
          notification_id: notification_id
        )

        notify_success(response)
      rescue Faraday::ConnectionFailed => e
        notify_failure(e.message)
      rescue MissingFileSetError => e
        notify_failure(e.message)
      rescue defined?(Coarnotify::ValidationError) ? Coarnotify::ValidationError : StandardError => e
        notify_failure(e.respond_to?(:errors) ? format_validation_errors(e) : e.message)
      rescue Exception => e
        notify_failure(e.message)
        raise
      end

      private

      def build_payload
        {
          "@context": %w[https://www.w3.org/ns/activitystreams https://coar-notify.net],
          "id": notification_id,
          "actor": {
            "id": "mailto:#{user.email}",
            "name": user.respond_to?(:display_name) ? user.display_name : user.email,
            "type": "Person"
          },
          "object": {
            "id": work_url,
            "ietf:cite-as": work_doi || work_url,
            "ietf:item": ietf_item,
            "type": %w[page sorg:AboutPage]
          },
          "origin": {
            "id": repository_url,
            "inbox": origin_inbox_url,
            "type": "Service"
          },
          "target": {
            "id": target.service_url,
            "inbox": target.inbox_url,
            "type": "Service"
          },
          "type": %w[Offer coar-notify:EndorsementAction]
        }
      end

      # A fresh id for every request, sent as the notification's id and stored on the NotifyRequest:
      # a reply names it in `inReplyTo`, which is how the reply is matched back to this request.
      def notification_id
        @notification_id ||= "urn:uuid:#{SecureRandom.uuid}"
      end

      def origin_inbox_url
        Hyrax::CoarNotify.config.inbox_url ||
          "#{Hyrax::CoarNotify.config.base_url || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::BASE_URL : '')}/coar_notify_inbox/notifications"
      end

      def notify_success(response)
        notify(
          I18n.t(
            "coar_notify.request_endorsement_notification.success_body",
            work_link: work_link,
            response_body: response.body,
            default: "Endorsement requested successfully for #{work_link}: #{response.body}"
          )
        )
      end

      def notify_failure(message)
        notify(
          I18n.t(
            "coar_notify.request_endorsement_notification.failure_body",
            work_link: work_link,
            response_body: message,
            default: "Failed to request endorsement for #{work_link}: #{message}"
          )
        )
      end

      def notify(message)
        if defined?(Hyrax::MessengerService)
          begin
            Hyrax::MessengerService.deliver(
              user,
              recipients,
              message,
              I18n.t("coar_notify.request_endorsement_notification.subject", default: "COAR Notify: Endorsement Request")
            )
          rescue StandardError => e
            Rails.logger.warn("Hyrax::MessengerService delivery failed: #{e.message}")
          end
        else
          Rails.logger.info("Notify message to #{recipients.map(&:email).join(', ')}: #{message}")
        end
      end

      def recipients
        depositor_email = work.respond_to?(:depositor) ? (work.depositor.is_a?(Array) ? work.depositor.first : work.depositor) : nil
        depositor_user = defined?(::User) ? ::User.find_by(email: depositor_email) : nil
        @recipients ||= [user, depositor_user].compact.uniq
      end

      def work_link
        @work_link ||= ActionController::Base.helpers.link_to(
          work.id.to_s,
          work_url,
          target: "_blank"
        )
      end

      def format_validation_errors(error)
        error.errors.map { |field, msg| "#{field}: #{msg}" }.join(", ")
      end

      def work_url
        "#{repository_url}/concern/#{work.class.to_s.underscore.pluralize}/#{work.id}"
      end

      def work_doi
        if work.respond_to?(:doi) && work.doi.present?
          work.doi.is_a?(Array) ? work.doi.first : work.doi
        elsif work.respond_to?(:identifier) && work.identifier.present?
          work.identifier.is_a?(Array) ? work.identifier.first : work.identifier
        end
      end

      def request_type
        REQUEST_TYPE
      end

      def duplicate_request?
        NotifyRequestLogger.duplicate_request?(
          work_id: work.id,
          request_type: request_type
        )
      end

      def repository_url
        ENV.fetch("APPLICATION_URL", "http://localhost:3000")
      end

      def ietf_item
        return unless file_set

        {
          id: download_url(file_set),
          mediaType: file_set.original_file&.mime_type,
          type: [
            'Article',
            'sorg:ScholarlyArticle'
          ]
        }
      end

      def file_set
        @file_set ||= begin
          file_sets = if defined?(Hyrax.query_service)
                        Hyrax.query_service.find_members(resource: work).select(&:file_set?)
                      elsif work.respond_to?(:file_sets)
                        work.file_sets
                      else
                        []
                      end

          found_fs = file_sets.find do |fs|
            PREFERRED_MIME_TYPES.include?(fs.original_file&.mime_type)
          end || file_sets.first

          raise MissingFileSetError, I18n.t('coar_notify.request_endorsement_notification.fileset_missing', default: "No file set found for work") unless found_fs

          found_fs
        end
      end

      def download_url(file_set)
        "#{repository_url}/downloads/#{file_set.id}"
      end
    end
  end
end
