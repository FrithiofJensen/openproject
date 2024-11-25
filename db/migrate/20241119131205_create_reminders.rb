class CreateReminders < ActiveRecord::Migration[7.1]
  def change
    create_table :reminders do |t|
      t.references :remindable, polymorphic: true, null: false
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :notification, foreign_key: true
      t.datetime :remind_at, null: false
      t.string :job_id
      t.string :note

      t.timestamps
    end

    add_index :reminders, :notification_id,
              unique: true,
              where: "notification_id IS NOT NULL",
              name: "index_reminders_on_notification_id_unique"
  end
end
