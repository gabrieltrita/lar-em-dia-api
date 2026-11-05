class CategoryPolicy < ApplicationPolicy
  def index? = true
  def create? = admin?
  def update? = admin?
  def manage? = admin?

  class Scope < Scope
    def resolve
      scope.active
    end
  end
end
