class CreateNotifyRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :notify_requests do |t|
      t.string :work_id, null: false
      t.references :notify_service, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :request_type, null: false
      t.string :status, null: false, default: "sent"
      t.string :notification_id
      t.timestamps
    end

    add_index :notify_requests, [:work_id, :notify_service_id, :request_type], name: "index_notify_requests_on_work_service_type"
    add_index :notify_requests, :notification_id, unique: true
    add_index :notify_requests, :status
  end
end
