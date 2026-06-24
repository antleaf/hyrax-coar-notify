class RequestEndorsementJob < ApplicationJob
  queue_as :default

  def perform(work_id:, service_id:, user_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    target = NotifyService.find(service_id)
    user = User.find(user_id)

    RequestEndorsement.new(
      work: work,
      target: target,
      user: user
    ).call
  end
end
