class SettingsController < ApplicationController
  before_action :set_user
  before_action :set_tags, only: [:show]

  def show
  end

  def update
    tab = params[:user]&.delete(:_tab)&.to_sym || :preferences
    if @user.update(user_preferences_params)
      redirect_to settings_path(tab: tab), notice: "Modifications enregistrées."
    else
      @tags = load_tags_with_counts
      params[:tab] = tab.to_s
      render :show, status: :unprocessable_entity
    end
  end

  def export
    exp = ExportService.new(@user)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')

    case params[:export_format].to_s
    when "json"
      send_data exp.json_export, filename: "mindsnap_export_#{timestamp}.json",
                                 type: "application/json"
    when "markdown"
      send_data exp.markdown_export_zip, filename: "mindsnap_export_#{timestamp}.zip",
                                         type: "application/zip"
    when "pdf"
      send_data exp.pdf_export, filename: "mindsnap_export_#{timestamp}.pdf",
                                type: "application/pdf"
    else
      redirect_to settings_path(tab: :data), alert: "Format d'export invalide."
    end
  end

  def export_by_tags
    tag_ids = params[:tag_ids]
    return redirect_to settings_path(tab: :data), alert: "Aucun tag sélectionné." if tag_ids.blank?

    tags = @user.tags.where(id: tag_ids)
    return redirect_to settings_path(tab: :data), alert: "Tags introuvables." if tags.empty?

    exp = ExportService.new(@user)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')

    case params[:export_format].to_s
    when "json"
      send_data exp.json_export_by_tags(tags), filename: "mindsnap_tags_#{timestamp}.json",
                                               type: "application/json"
    when "markdown"
      send_data exp.markdown_export_by_tags_zip(tags), filename: "mindsnap_tags_#{timestamp}.zip",
                                                       type: "application/zip"
    when "pdf"
      send_data exp.pdf_export_by_tags(tags), filename: "mindsnap_tags_#{timestamp}.pdf",
                                              type: "application/pdf"
    else
      redirect_to settings_path(tab: :data), alert: "Format d'export invalide."
    end
  end

  def clear_history
    count = @user.conversations.count
    @user.conversations.destroy_all
    redirect_to settings_path(tab: :data), notice: "#{count} conversation(s) supprimée(s)."
  end

  private

  def set_user
    @user = current_user
  end

  def set_tags
    @tags = load_tags_with_counts
  end

  def load_tags_with_counts
    @user.tags
         .left_joins(:taggings)
         .group(:id)
         .select("tags.*, COUNT(taggings.id) AS taggings_count")
         .order(:name)
  end

  def user_preferences_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :avatar,
      :preferred_language,
      :summary_length,
      :auto_tagging,
      :tts_voice,
      :default_view
    )
  end
end
