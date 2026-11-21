class CategoryPolicy < ApplicationPolicy
  def index? = true
  def create? = admin?
  def update? = admin?
  def manage? = admin?
  def create_own? = true
  def manage_own? = record.user_id == user.id

  class Scope < Scope
    def resolve
      scope.active.available_to(user)
    end
  end
end
