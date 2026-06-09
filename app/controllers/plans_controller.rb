class PlansController < ApplicationController
  def update
    plan = params[:plan]
    if User::PLANS.key?(plan)
      current_user.update!(plan: plan)
      redirect_to dashboard_path, notice: "Plan mis à jour : #{current_user.plan_label} ✓"
    else
      redirect_to dashboard_path, alert: "Plan invalide."
    end
  end
end
