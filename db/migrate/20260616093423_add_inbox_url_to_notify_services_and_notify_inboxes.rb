class AddInboxUrlToNotifyServicesAndNotifyInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :notify_services, :inbox_url, :string
    add_column :notify_inboxes, :inbox_url, :string
  end
end
