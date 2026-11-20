# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_20_002000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "allocation_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "reserve_account_id"
    t.text "name", null: false
    t.string "mode", null: false
    t.bigint "amount_cents"
    t.integer "percent_bps"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reserve_account_id"], name: "index_allocation_targets_on_reserve_account_id"
    t.index ["user_id", "position"], name: "index_allocation_targets_on_user_id_and_position"
    t.index ["user_id"], name: "index_allocation_targets_on_user_remainder", unique: true, where: "((mode)::text = 'remainder'::text)"
  end

  create_table "allocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "target_id", null: false
    t.uuid "entry_id", null: false
    t.date "month", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_allocations_on_entry_id", unique: true
    t.index ["target_id", "month"], name: "index_allocations_on_target_id_and_month", unique: true
    t.index ["user_id", "month"], name: "index_allocations_on_user_id_and_month"
  end

  create_table "asset_distributions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.uuid "user_id"
    t.string "kind", null: false
    t.string "source", null: false
    t.date "record_on", null: false
    t.date "paid_on"
    t.bigint "amount_per_share_e8", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "kind", "record_on"], name: "index_asset_distributions_on_cvm_record", unique: true, where: "((source)::text = 'cvm'::text)"
    t.index ["asset_id", "record_on"], name: "index_asset_distributions_on_asset_id_and_record_on"
    t.index ["user_id", "record_on"], name: "index_asset_distributions_on_user_id_and_record_on"
  end

  create_table "asset_indicators", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.date "computed_on", null: false
    t.bigint "price_cents"
    t.bigint "dy_12m_bps"
    t.bigint "distribution_average_e8"
    t.bigint "distribution_median_e8"
    t.integer "years_paying"
    t.bigint "payout_bps"
    t.bigint "p_vp_e2"
    t.bigint "p_l_e2"
    t.bigint "roe_average_bps"
    t.bigint "earnings_cagr_bps"
    t.bigint "equity_cagr_bps"
    t.integer "years_with_profit"
    t.bigint "net_margin_bps"
    t.bigint "net_debt_to_equity_bps"
    t.bigint "liquidity_cents"
    t.integer "financial_years"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_asset_indicators_on_asset_id", unique: true
  end

  create_table "asset_quotes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.date "quoted_on", null: false
    t.bigint "close_cents", null: false
    t.bigint "volume_cents", null: false
    t.integer "trades_count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "quoted_on"], name: "index_asset_quotes_on_asset_id_and_quoted_on", unique: true
  end

  create_table "assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ticker", null: false
    t.string "isin", null: false
    t.string "name", null: false
    t.string "asset_type", null: false
    t.string "cnpj"
    t.string "sector"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_type", "active"], name: "index_assets_on_asset_type_and_active"
    t.index ["cnpj"], name: "index_assets_on_cnpj"
    t.index ["isin"], name: "index_assets_on_isin"
    t.index ["ticker"], name: "index_assets_on_ticker", unique: true
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id"
    t.string "action", null: false
    t.string "target_type"
    t.uuid "target_id"
    t.jsonb "metadata", default: {}, null: false
    t.text "ip_address"
    t.text "user_agent"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
  end

  create_table "balances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.bigint "amount_cents", null: false
    t.date "as_of", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "as_of"], name: "index_balances_on_user_id_and_as_of", unique: true
    t.index ["user_id"], name: "index_balances_on_user_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "default_nature"
    t.index ["key"], name: "index_categories_on_key", unique: true
    t.index ["kind", "position"], name: "index_categories_on_kind_and_position"
  end

  create_table "company_financials", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cnpj", null: false
    t.integer "fiscal_year", null: false
    t.bigint "revenue_cents", null: false
    t.bigint "net_income_cents", null: false
    t.bigint "equity_cents", null: false
    t.bigint "net_debt_cents"
    t.bigint "dividends_paid_cents"
    t.bigint "shares_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cnpj", "fiscal_year"], name: "index_company_financials_on_cnpj_and_fiscal_year", unique: true
  end

  create_table "consents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind", null: false
    t.string "version", null: false
    t.boolean "granted", null: false
    t.text "ip_address"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.index ["user_id", "kind", "created_at"], name: "index_consents_on_user_id_and_kind_and_created_at"
    t.index ["user_id"], name: "index_consents_on_user_id"
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "category_id", null: false
    t.string "kind", null: false
    t.text "description", null: false
    t.bigint "amount_cents", null: false
    t.date "due_on", null: false
    t.string "status", default: "pending", null: false
    t.date "paid_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nature"
    t.uuid "series_id"
    t.integer "series_position"
    t.index ["category_id"], name: "index_entries_on_category_id"
    t.index ["series_id"], name: "index_entries_on_series_id"
    t.index ["user_id", "due_on"], name: "index_entries_on_user_id_and_due_on"
    t.index ["user_id", "kind", "due_on"], name: "index_entries_on_user_id_and_kind_and_due_on"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "entry_series", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind", null: false
    t.integer "entries_count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "total_cents"
    t.integer "interval_months", default: 1, null: false
    t.index ["user_id"], name: "index_entry_series_on_user_id"
  end

  create_table "fund_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.date "reference_month", null: false
    t.bigint "equity_cents", null: false
    t.bigint "book_value_per_share_e8", null: false
    t.bigint "shares_count", null: false
    t.integer "shareholders_count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "reference_month"], name: "index_fund_reports_on_asset_id_and_reference_month", unique: true
  end

  create_table "identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "provider", null: false
    t.text "provider_uid", null: false
    t.text "email_at_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_uid"], name: "index_identities_on_provider_and_provider_uid", unique: true
    t.index ["user_id", "provider"], name: "index_identities_on_user_id_and_provider", unique: true
  end

  create_table "interest_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "series", null: false
    t.date "rate_on", null: false
    t.bigint "rate_e8", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["series", "rate_on"], name: "index_interest_rates_on_series_and_rate_on", unique: true
  end

  create_table "investment_positions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "asset_id", null: false
    t.string "goal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_investment_positions_on_asset_id"
    t.index ["user_id", "asset_id"], name: "index_investment_positions_on_user_id_and_asset_id", unique: true
  end

  create_table "investment_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "position_id", null: false
    t.uuid "entry_id"
    t.string "kind", null: false
    t.date "traded_on", null: false
    t.bigint "quantity", null: false
    t.bigint "price_cents"
    t.bigint "fees_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_investment_transactions_on_entry_id", unique: true
    t.index ["position_id", "traded_on"], name: "index_investment_transactions_on_position_id_and_traded_on"
    t.index ["user_id", "traded_on"], name: "index_investment_transactions_on_user_id_and_traded_on"
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.text "user_agent"
    t.text "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "family_id", default: -> { "gen_random_uuid()" }, null: false
    t.datetime "session_started_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "revoked_reason"
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["family_id"], name: "index_refresh_tokens_on_family_id"
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_refresh_tokens_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "reserve_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.text "name", null: false
    t.string "kind", null: false
    t.integer "cdi_percent_bps"
    t.integer "annual_rate_bps"
    t.boolean "tax_exempt", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_reserve_accounts_on_user_id"
  end

  create_table "reserve_movements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "account_id", null: false
    t.uuid "entry_id"
    t.string "kind", null: false
    t.date "moved_on", null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "moved_on"], name: "index_reserve_movements_on_account_id_and_moved_on"
    t.index ["entry_id"], name: "index_reserve_movements_on_entry_id", unique: true
    t.index ["user_id", "moved_on"], name: "index_reserve_movements_on_user_id_and_moved_on"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "email", null: false
    t.text "first_name", null: false
    t.text "last_name"
    t.text "phone"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "password_changed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "confirmed_at"
    t.text "unconfirmed_email"
    t.integer "failed_login_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.text "otp_secret"
    t.datetime "otp_enabled_at"
    t.bigint "otp_last_used_step"
    t.string "otp_backup_code_digests", default: [], null: false, array: true
    t.datetime "anonymized_at"
    t.datetime "deactivated_at"
    t.string "time_zone", default: "America/Sao_Paulo", null: false
    t.boolean "due_alerts_enabled", default: true, null: false
    t.integer "due_alert_days_before", default: 1, null: false
    t.date "due_alerts_sent_on"
    t.integer "reserve_goal_months", default: 6, null: false
    t.bigint "reserve_goal_cents"
    t.index ["anonymized_at"], name: "index_users_on_anonymized_at"
    t.index ["confirmed_at"], name: "index_users_on_confirmed_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "allocation_targets", "reserve_accounts", on_delete: :nullify
  add_foreign_key "allocation_targets", "users"
  add_foreign_key "allocations", "allocation_targets", column: "target_id", on_delete: :cascade
  add_foreign_key "allocations", "entries", on_delete: :cascade
  add_foreign_key "allocations", "users"
  add_foreign_key "asset_distributions", "assets"
  add_foreign_key "asset_distributions", "users"
  add_foreign_key "asset_indicators", "assets"
  add_foreign_key "asset_quotes", "assets"
  add_foreign_key "audit_logs", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "balances", "users"
  add_foreign_key "consents", "users", on_delete: :cascade
  add_foreign_key "entries", "categories"
  add_foreign_key "entries", "entry_series", column: "series_id"
  add_foreign_key "entries", "users"
  add_foreign_key "entry_series", "users"
  add_foreign_key "fund_reports", "assets"
  add_foreign_key "identities", "users"
  add_foreign_key "investment_positions", "assets"
  add_foreign_key "investment_positions", "users"
  add_foreign_key "investment_transactions", "entries", on_delete: :nullify
  add_foreign_key "investment_transactions", "investment_positions", column: "position_id"
  add_foreign_key "investment_transactions", "users"
  add_foreign_key "refresh_tokens", "users", on_delete: :cascade
  add_foreign_key "reserve_accounts", "users"
  add_foreign_key "reserve_movements", "entries", on_delete: :nullify
  add_foreign_key "reserve_movements", "reserve_accounts", column: "account_id", on_delete: :cascade
  add_foreign_key "reserve_movements", "users"
end
