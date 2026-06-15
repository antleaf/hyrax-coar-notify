namespace :notify do
  desc 'Setup Hyrax, will read from specified file usage: notify:setup_hyrax["setup.json"]'
  task :"setup_hyrax", [:seedfile] => :environment do |task, args|
    seedfile = args.seedfile
    unless args.seedfile.present?
      seedfile = Rails.root.join("seed","setup.json")
    end

    if (File.exist?(seedfile))
      puts("Running hyrax setup from seedfile: #{seedfile}")
    else
      abort("ERROR: missing seedfile for hyrax setup: #{seedfile}")
    end

    seed = JSON.parse(File.read(seedfile))

    ##############################################
    # make the requested users
    ######
    Rake::Task['notify:setup_default_roles'].invoke
    admin = Role.find_by(name: "admin")
    seed["users"].each do |user|
      newUser = User.where(email: user["email"]).first_or_create!(password: user["password"], display_name: user["name"])
      if user["role"] == "admin"
        unless admin.users.include?(newUser)
          admin.users << newUser
          admin.save!
        end
      end
    end

    # finished creating users
    ##############################################


    ##############################################
    # Create default administrative set and load workflow
    ######
    Rake::Task['hyrax:default_admin_set:create'].invoke
    Rake::Task['hyrax:workflow:load'].invoke
    Rake::Task['hyrax:default_collection_types:create'].invoke

    ##############################################
    # Create languages controlled vocabulary
    ######
    Rake::Task['hyrax:controlled_vocabularies:language'].invoke if Qa::Authorities::Local.subauthority_for('languages').all.size == 0
  end
end
