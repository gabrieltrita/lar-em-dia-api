class CategoryPolicy < ApplicationPolicy
  def index? = true

  class Scope < Scope
    def resolve
      scope.active
    end
  end
end
