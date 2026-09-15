class CreateNotifyInboxes < ActiveRecord::Migration[7.2]
  def change
    create_table :notify_inboxes do |t|
      t.string :title
      t.string :service_url
      t.string :api_key
      if connection.adapter_name.downcase.include?('postgres')
        t.string :target_uris, array: true, default: []
      else
        t.text :target_uris
      end
      t.boolean :status

      t.timestamps
    end
  end
end
