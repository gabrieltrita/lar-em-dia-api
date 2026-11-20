class AllocationPolicy < ApplicationPolicy
  def create? = true
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
