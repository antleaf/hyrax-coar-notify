class NotifyServicesController < ApplicationController
  load_and_authorize_resource
  with_themed_layout 'dashboard'

  def new
    @notify_service = NotifyService.new
  end

  def create
    @notify_service = NotifyService.new(notify_service_params)

    if @notify_service.save
      redirect_to manage_notify_connections_path,
                  notice: "Notify Service created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @notify_service.update(notify_service_params)
      redirect_to manage_notify_connections_path,
                  notice: "Notify Service updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notify_service.destroy

    redirect_to manage_notify_connections_path,
                notice: "Notify Service deleted successfully."
  end

  def request_endorsement
    RequestEndorsementJob.perform_later(
      work_id: params[:work_id],
      service_id: @notify_service.id,
      user_id: current_user.id
    )

    flash[:notice] = I18n.t("request_endorsement_notification.queued")
    redirect_to request.referer
  end

  def request_review
    RequestReviewJob.perform_later(
      work_id: params[:work_id],
      service_id: @notify_service.id,
      user_id: current_user.id
    )

    flash[:notice] = I18n.t("request_review_notification.queued")
    redirect_to request.referer
  end

  private

  def notify_service_params
    params.require(:notify_service).permit(
      :title,
      :service_url,
      :inbox_url,
      :api_key,
      :status,
      origin_uris: []
    )
  end
end