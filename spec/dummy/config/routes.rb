# frozen_string_literal: true

Rails.application.routes.draw do
  mount Hyrax::CoarNotify::Engine => '/coar_notify'
end
