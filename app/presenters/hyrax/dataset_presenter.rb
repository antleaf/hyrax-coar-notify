# Generated via
#  `rails generate hyrax:work Dataset`
module Hyrax
  class DatasetPresenter < Hyrax::WorkShowPresenter
    def notify_services
      @notify_services ||= NotifyService.order(created_at: :desc)
    end
  end
end
