class AddRevokedReasonToRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :refresh_tokens, :revoked_reason, :string
  end
end
