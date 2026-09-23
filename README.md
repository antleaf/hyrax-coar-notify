# Hyrax COAR Notify
This is designed to implement the [COAR Notify Protocol (v1.0.1)](https://coar-notify.net/specification/1.0.1/)  in [Samvera Hyrax](https://github.com/samvera/hyrax) (v5.2), and support three COAR Notify workflows:

- https://coar-notify.net/catalogue/workflows/pci-sciety/
- https://coar-notify.net/catalogue/workflows/repository-pci/
- https://coar-notify.net/catalogue/workflows/repository-relationship-repository/

It depends on the [COAR-Notify Inbox Rails Engine](https://github.com/antleaf/coar-notify-inbox-rails-engine)

See [Installing Hyrax COAR Notify](docs/INSTALLATION.md) for how to add this gem to a Hyrax host
application and wire it up. For a complete, working example, see the
[demonstrator app](https://github.com/antleaf/hyrax-coar-notify-demonstrator).

The document [wireframes.pdf](docs/Wireframes.pdf)  created as a part of the design process for Hyrax Notify has the wireframes designs. The images for it are at [Wireframe images](docs/Wireframe images/)

The document [Hyrax Notify with external inbox](docs/Hyrax%20Notify%20with%20external%20inbox.md) details how Hyrax Notify is to be used to send and receive Notify notifications, when configured with an external inbox.



## Access control

Every page of the engine requires a signed-in user (the host's `authenticate_user!`). The Notify dashboard and the pages for managing services and inboxes are then limited to:

- admins (`Ability#admin?` or `User#admin?`),
- users holding the role named by `Hyrax::CoarNotify.config.manager_role` (default `admin`, set with the `NOTIFY_MANAGER_ROLE` environment variable), and
- anyone your `Ability` grants `can :access, :coar_notify`.

Everyone else is redirected to the home page with an alert, and anonymous visitors are sent to sign in. A user's roles are read from `current_user.groups`, as provided by hydra-role-management.

## Fetching notifications

Incoming notifications are pulled by `Hyrax::CoarNotify::FetchNotificationsJob`, on the cron schedule in `Hyrax::CoarNotify.config.fetch_schedule` (default every 5 minutes, set with `config.fetch_schedule` in `config/initializers/hyrax_coar_notify_config.rb`).

If your host app has [sidekiq-scheduler](https://github.com/sidekiq-scheduler/sidekiq-scheduler) loaded, the engine registers this schedule automatically on Sidekiq server startup, alongside whatever other jobs you already have scheduled. Nothing further is required.

If you don't use sidekiq-scheduler, nothing schedules the job for you: run `Hyrax::CoarNotify::FetchNotificationsJob.perform_later` on your own schedule instead, e.g. with `whenever`, a system cron entry calling `rails runner`, or another scheduler of your choice.
