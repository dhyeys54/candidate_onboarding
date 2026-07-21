class CreateOnboardingRegions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_regions do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :onboarding_regions, :name, unique: true
  end
end
