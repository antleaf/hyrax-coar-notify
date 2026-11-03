namespace :notify do
  desc 'Setup Hyrax, will read from specified file usage: notify:setup_default_roles'
  task :"setup_default_roles", [:seedfile] => :environment do |task, args|
    admin = Role.where(name: "admin").first_or_create!
    review_service_manager = Role.where(name: "review_service_manager").first_or_create!
  end
end