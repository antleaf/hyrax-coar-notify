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

  private

  def set_notify_service
    @notify_service = NotifyService.find(params[:id])
  end

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