class CreateNotifyInboxes < ActiveRecord::Migration[7.2]
  def change
    create_table :notify_inboxes do |t|
      t.string :title
      t.string :service_url
      t.string :api_key
      t.string :target_urls, array: true, default: []
      t.boolean :status

      t.timestamps
    end
  end
end
