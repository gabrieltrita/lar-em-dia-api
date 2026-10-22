module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: %i[show update destroy unlock reset_two_factor]

        # GET /api/v1/admin/users?page=1&limit=20&role=admin&email=foo@bar.com
        # Obs.: nome/telefone são criptografados de forma não-determinística,
        # por isso não dá para filtrar por eles no banco. E-mail aceita busca exata.
        def index
          authorize User
          scope = policy_scope(User).not_anonymized.order(created_at: :desc)
          scope = scope.where(role: params[:role]) if params[:role].present? && User.roles.key?(params[:role])
          scope = scope.where(email: params[:email].to_s) if params[:email].present?

          pagy, users = pagy(scope)
          render json: { data: UserBlueprint.render_as_hash(users, view: :admin), meta: pagination_meta(pagy) }
        end

        # GET /api/v1/admin/users/:id
        def show
          authorize @user
          render json: { data: UserBlueprint.render_as_hash(@user, view: :admin) }
        end

        # POST /api/v1/admin/users
        # Usuário criado pelo admin já nasce com e-mail confirmado.
        def create
          user = User.new(user_params.merge(confirmed_at: Time.current))
          authorize user

          if user.save
            AuditLog.record!("user.created", target: user, metadata: { role: user.role })
            render json: { data: UserBlueprint.render_as_hash(user, view: :admin) }, status: :created
          else
            render_validation_errors(user)
          end
        end

        # PATCH /api/v1/admin/users/:id
        # Troca de role e de senha são auditadas pelo model; troca de senha
        # derruba todas as sessões do usuário.
        def update
          authorize @user
          attrs = user_params
          authorize @user, :change_role? if attrs.key?(:role) && attrs[:role] != @user.role

          if @user.update(attrs)
            changed = @user.saved_changes.keys - %w[updated_at password_digest password_changed_at role]
            AuditLog.record!("user.updated", target: @user, metadata: { fields: changed }) if changed.any?
            render json: { data: UserBlueprint.render_as_hash(@user, view: :admin) }
          else
            render_validation_errors(@user)
          end
        end

        # DELETE /api/v1/admin/users/:id  -> anonimiza (LGPD), não apaga.
        def destroy
          authorize @user
          @user.anonymize!
          AuditLog.record!("user.anonymized", target: @user, metadata: { by: "admin" })
          head :no_content
        end

        # POST /api/v1/admin/users/:id/unlock
        def unlock
          authorize @user
          @user.unlock!
          AuditLog.record!("user.unlocked", target: @user)
          render json: { data: UserBlueprint.render_as_hash(@user, view: :admin) }
        end

        # DELETE /api/v1/admin/users/:id/two_factor
        # Para quem perdeu o celular e os códigos de backup.
        def reset_two_factor
          authorize @user
          @user.disable_two_factor!
          @user.revoke_all_sessions!
          AuditLog.record!("two_factor.reset", target: @user)
          UserMailer.two_factor_disabled(@user).deliver_later
          head :no_content
        end

        private

        def set_user
          @user = User.not_anonymized.find(params[:id])
        end

        def user_params
          params.permit(:email, :first_name, :last_name, :phone, :role, :password, :password_confirmation)
        end
      end
    end
  end
end
