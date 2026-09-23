# Installing Hyrax COAR Notify

This covers adding the gem to a Hyrax 5.2+ host application and wiring it up. For the COAR
Notify protocol workflow itself (sending/receiving notifications via an external inbox), see
[Hyrax Notify with external inbox](Hyrax%20Notify%20with%20external%20inbox.md). For access
control and the notification-fetching schedule, see the main [README](../README.md).

## Requirements

- Rails ~> 7.2
- Hyrax ~> 5.2
- A running [COAR-Notify Inbox](https://github.com/antleaf/coar-notify-inbox-rails-engine) to send to and receive from

## 1. Add the gem

```ruby
# Gemfile
gem "hyrax-coar-notify"
```

```sh
bundle install
```

## 2. Run the install generator

```sh
rails generate hyrax:coar_notify:install
```

This does five things:

- copies `config/initializers/hyrax_coar_notify.rb`, with every setting commented out and documented
- copies `config/metadata/coar_notify_metadata.yaml`, defining the `doi`, `endorsements`, `reviews`,
  `has_endorsement` and `has_review` attributes
- mounts the engine at `/coar_notify` in `config/routes.rb`
- installs and runs the engine's migrations (`notify_services`, `notify_inboxes`, `notify_requests`)
- adds a "COAR Notify" link to `app/views/hyrax/dashboard/_sidebar.html.erb`, if that file exists in
  your app (it's a no-op if you haven't generated/customized that partial)

If step 4 doesn't run for you (some Rails versions don't propagate a generator's own migrations
automatically), run it yourself:

```sh
rails hyrax_coar_notify:install:migrations
rails db:migrate
```

## 3. Add the metadata to your work types

The generator copies the metadata YAML, but Hyrax only applies a `config/metadata/*.yaml` file to a
work type that explicitly asks for it. **Without this step, nothing in this gem will actually work**
against your works: `NotificationFetcher` checks `work.respond_to?(:endorsements=)` before writing
anything, so a work type that hasn't included this schema silently never records an endorsement or
review, no matter how many notifications arrive.

For every work type (e.g. `app/models/dataset_resource.rb`) that should support COAR Notify
endorsement/review requests, add the schema and indexer:

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

(If you're still on an ActiveFedora-based work model rather than a Valkyrie resource, define the
equivalent `property :endorsements, predicate: ..., multiple: true`-style attributes yourself instead
of `Hyrax::Schema` — see Hyrax's own ActiveFedora work generator for the pattern.)

## 4. Presenter and model behavior

- **Automatic:** `Hyrax::CoarNotify::WorkShowPresenterBehavior` (endorsements/reviews on the work
  show page, the "request endorsement/review" buttons) is included into `Hyrax::WorkShowPresenter`
  by the engine itself. No action needed.
- **Optional:** `Hyrax::CoarNotify::WorkBehavior` adds `#duplicate_endorsement_request?`,
  `#duplicate_review_request?`, `#parsed_endorsements` and `#parsed_reviews` directly on a work
  instance (reading the work's own attributes, not Solr). Nothing in the gem requires this — include
  it on a work type yourself only if you want those methods available on the model.

## 5. Configure the initializer

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

## Verifying it worked

- Sign in as an admin (or a user with the `manager_role`) and visit `/coar_notify` — you should see
  the Notify dashboard.
- On a work of a type from step 3, the endorsement/review request buttons should appear for an
  editor of that work.
- See the [demonstrator app](https://github.com/antleaf/hyrax-coar-notify-demonstrator) for a
  complete, working Hyrax host wired up with this gem, if you want to see it end-to-end.
