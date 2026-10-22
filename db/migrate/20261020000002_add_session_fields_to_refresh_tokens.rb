class AddSessionFieldsToRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    # family_id identifica a "sessão" (dispositivo): se mantém entre rotações.
    add_column :refresh_tokens, :family_id, :uuid, null: false, default: -> { "gen_random_uuid()" }
    add_column :refresh_tokens, :session_started_at, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" }
    add_index :refresh_tokens, :family_id
    add_index :refresh_tokens, :expires_at
  end
end
