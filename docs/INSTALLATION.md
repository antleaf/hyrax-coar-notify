# Installing Hyrax COAR Notify

This walks through adding the gem to a Hyrax 5.2+ host application, from a plain Hyrax app to a working
Notify setup. For the COAR Notify protocol workflow itself (sending/receiving notifications via an
external inbox), see [Hyrax Notify with external inbox](Hyrax%20Notify%20with%20external%20inbox.md). For
access control and the notification-fetching schedule, see the main [README](../README.md).

## Starting point

You have a Hyrax app that:

- runs Rails ~> 7.2 and Hyrax ~> 5.2, created following
  [Developing your Hyrax-based app](https://github.com/samvera/hyrax/blob/main/documentation/developing-your-hyrax-based-app.md#creating-a-hyrax-based-app)
- uses Redis and Sidekiq as its ActiveJob backend
- has at least one work type (e.g. `rails generate hyrax:work_resource Dataset`)
- has an admin user
- can reach a running [COAR-Notify Inbox](https://github.com/antleaf/coar-notify-inbox-rails-engine) to send
  to and receive from. The inbox is a separate service; this gem talks to it over HTTP.

The [demonstrator app](https://github.com/antleaf/hyrax-coar-notify-demonstrator) is a complete host built
by following exactly these steps.

## 1. Add the gems

```ruby
# Gemfile
gem "hyrax-coar-notify", github: "antleaf/hyrax-coar-notify"

# A hard dependency of hyrax-coar-notify. It is not published to RubyGems, and a gemspec cannot carry a
# git source, so your Gemfile has to say where to find it. Its engine is loaded but not mounted when you
# use an external inbox.
gem "coar_notify_inbox", git: "https://github.com/antleaf/coar-notify-inbox-rails-engine"

# Optional, but needed for the automatic notification-fetch schedule (see step 7)
gem "sidekiq-scheduler"
```

```sh
bundle install
```

## 2. Set the environment variables

The gem reads these (all optional; step 8 shows how each maps to an initializer setting):

| Variable | Purpose |
|---|---|
| `COAR_NOTIFY_USE_LOCAL` | `true` if the inbox is mounted in this same app, `false` for a separate service (default `true`) |
| `COAR_NOTIFY_BASE_URL` | Base URL of the inbox service |
| `COAR_NOTIFY_INBOX_URL` | Full URL notifications are fetched from (falls back to `base_url` + a standard path) |
| `COAR_NOTIFY_ADMIN_API_TOKEN` | Bearer token for the inbox's admin API |
| `COAR_NOTIFY_DEFAULT_ORIGIN_INBOX` | Default origin inbox URL sent with outgoing requests |
| `COAR_NOTIFY_INBOX_USERNAME` | Sent when registering a consumer; only effective with an inbox admin token |
| `NOTIFY_MANAGER_ROLE` | Role allowed to manage Notify connections (default `admin`) |
| `APPLICATION_URL` | Public URL of your app, without a trailing slash; used to build the work URLs sent in requests (default `http://localhost:3000`) |

## 3. Run the install generator

```sh
rails generate hyrax:coar_notify:install
```

By default it wires every registered work type. To pick some, pass them by name:

```sh
rails generate hyrax:coar_notify:install --work-types Dataset Article
```

It does these things. Each one is skipped if its target file is missing, and the ones that edit your files
also skip, saying what to do by hand, when the file doesn't look as expected. All of them are safe to run
again:

- copies `config/initializers/hyrax_coar_notify.rb`, with every setting commented out and documented
- copies `config/metadata/coar_notify_metadata.yaml`, defining the `doi`, `endorsements`, `reviews`,
  `has_endorsement` and `has_review` attributes
- mounts the engine at `/coar_notify` by adding `mount Hyrax::CoarNotify::Engine => '/coar_notify'` to
  `config/routes.rb`
- copies the engine's migrations into `db/migrate` (it does **not** run them; see step 4)
- for each work type: adds `include Hyrax::Schema(:coar_notify_metadata)` to the model and
  `include Hyrax::Indexer(:coar_notify_metadata)` to its indexer, and creates
  `app/views/hyrax/<work types>/show.html.erb` (from Hyrax's own `base/show.html.erb`, or edits yours if it
  exists) with the endorsement/review partials added
- adds the Notify rules at the top of `custom_permissions` in `app/models/ability.rb`: admins and members
  of the `manager_role` can manage Notify services and inboxes and can `:access, :coar_notify`
- adds a "COAR Notify" link, shown only to users who can `:access, :coar_notify`, to
  `app/views/hyrax/dashboard/_sidebar.html.erb`, if that file exists in your app

Check the diff afterwards, in particular `config/routes.rb`, the work type files, and the show views.

## 4. Run the migrations

```sh
rails db:migrate
```

This creates `notify_services`, `notify_inboxes` and `notify_requests`. If the generator couldn't copy the
migrations, copy them yourself first with `rails hyrax_coar_notify:install:migrations`.

**Rails 7.2:** `coar_notify_inbox` ships migrations declared for `ActiveRecord::Migration[8.0]`, and its
engine's `db/migrate` is merged into your app even when you don't mount it. On Rails below 8, `db:migrate`
then fails with `Unknown migration version '8.0'`. Add an initializer to fix it, for example
`config/initializers/coar_notify_inbox_migration_compat.rb`:

```ruby
if Rails::VERSION::MAJOR < 8 && defined?(ActiveRecord::Migration::Compatibility)
  module ActiveRecord::Migration::Compatibility
    class << self
      prepend(Module.new do
        def find(version)
          super(version.to_s == "8.0" ? "7.2" : version)
        end
      end)
    end
  end
end
```

## 5. Check the work types

The generator makes the work type changes for you. **They are essential**: Hyrax only applies a
`config/metadata/*.yaml` file to a work type that asks for it, and `NotificationFetcher` checks
`work.respond_to?(:endorsements=)` before writing anything, so a work type without the schema silently
never records an endorsement or review, no matter how many notifications arrive.

Confirm each work type you want Notify on has these lines, and add them by hand if the generator skipped it:

```ruby
class DatasetResource < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:coar_notify_metadata)
end
```

```ruby
class DatasetResourceIndexer < Hyrax::Indexers::PcdmObjectIndexer(DatasetResource)
  include Hyrax::Indexer(:basic_metadata)
  include Hyrax::Indexer(:coar_notify_metadata)
end
```

and that its show view renders the two partials (the generator places them right after `show_actions` and
after the main card):

```erb
<%= render 'hyrax/coar_notify/shared/endorsement_actions', presenter: @presenter %>
<%= render 'hyrax/coar_notify/shared/endorsements_and_reviews', presenter: @presenter %>
```

The request buttons check permissions themselves, so only people who can edit the work see them.

(If you're still on an ActiveFedora-based work model rather than a Valkyrie resource, the generator skips
it: define the equivalent `property :endorsements, predicate: ..., multiple: true`-style attributes yourself
instead of `Hyrax::Schema`, as in Hyrax's own ActiveFedora work generator.)

## 6. Presenter and model behavior

- **Automatic:** `Hyrax::CoarNotify::WorkShowPresenterBehavior` (endorsements/reviews on the work
  show page, the "request endorsement/review" buttons) is included into `Hyrax::WorkShowPresenter`
  by the engine itself. No action needed.
- **Optional:** `Hyrax::CoarNotify::WorkBehavior` adds `#duplicate_endorsement_request?`,
  `#duplicate_review_request?`, `#parsed_endorsements` and `#parsed_reviews` directly on a work
  instance (reading the work's own attributes, not Solr). Nothing in the gem requires this: include
  it on a work type yourself only if you want those methods available on the model.

## 7. Schedule the notification fetch

With `sidekiq-scheduler` in your Gemfile (step 1), the engine schedules `FetchNotificationsJob` itself when
Sidekiq starts, using `fetch_schedule` (default every 5 minutes). Make sure your Sidekiq config processes the
queue the job runs on (`default`). Without `sidekiq-scheduler`, run
`Hyrax::CoarNotify::FetchNotificationsJob.perform_later` on your own schedule. See the README's "Fetching
notifications" section.

## 8. Configure the initializer

`config/initializers/hyrax_coar_notify.rb` (all optional; shown with their defaults / `ENV` var):

| Setting | Default | Purpose |
|---|---|---|
| `base_url` | `ENV["COAR_NOTIFY_BASE_URL"]` | Base URL of the `coar_notify_inbox` service, when not using `inbox_url`/`use_local` directly |
| `admin_api_token` | `ENV["COAR_NOTIFY_ADMIN_API_TOKEN"]` | Bearer token for the inbox's admin API (consumer registration, fetching) |
| `use_local` | `true` (`ENV["COAR_NOTIFY_USE_LOCAL"]`) | Whether the inbox is mounted in this same app vs. a separate service |
| `inbox_url` | `ENV["COAR_NOTIFY_INBOX_URL"]` | Full URL to fetch notifications from; falls back to `base_url` + a standard path |
| `default_origin_inbox` | `ENV["COAR_NOTIFY_DEFAULT_ORIGIN_INBOX"]` | Default origin inbox URL sent with outgoing requests |
| `fetch_schedule` | `*/5 * * * *` | Cron schedule for `FetchNotificationsJob` (see the README's "Fetching notifications" section) |
| `manager_role` | `admin` (`ENV["NOTIFY_MANAGER_ROLE"]`) | Role name that grants access to the Notify dashboard and connection management (see the README's "Access control" section) |
| `inbox_username` | `ENV["COAR_NOTIFY_INBOX_USERNAME"]` | Optional; sent when registering a consumer, effective only when `admin_api_token` authenticates as an inbox admin |

## Rake tasks

The gem ships three tasks for setting up a fresh host app:

```sh
rails db:exists                                  # exits 0 if the database is reachable, 1 otherwise
rails notify:setup_default_roles                 # creates the admin and review_service_manager roles
rails "notify:setup_hyrax[seed/setup.json]"      # roles, users from the seed file, default admin set, workflows, collection types, languages
```

`notify:setup_hyrax` reads a JSON seed file (default `seed/setup.json` in the host app) with a `users` list of
`{ "email", "password", "name", "role" }`; users with `"role": "admin"` get the admin role.

## Verifying it worked

- Sign in as an admin (or a user with the `manager_role`) and visit `/coar_notify`. You should see
  the Notify dashboard, and a "COAR Notify" link in the dashboard sidebar.
- Create a Notify service under "Manage connections"; it should appear in the list.
- On a work of a type from step 5, the endorsement/review request buttons should appear for an
  editor of that work once at least one active Notify service exists.
- See the [demonstrator app](https://github.com/antleaf/hyrax-coar-notify-demonstrator) for a
  complete, working Hyrax host wired up with this gem, if you want to see it end-to-end.
