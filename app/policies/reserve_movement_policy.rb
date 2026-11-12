class ReserveMovementPolicy < ApplicationPolicy
  def index? = true
  def create? = true
  def show? = owner?
  def update? = owner?
  def destroy? = owner?

  class Scope < Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
