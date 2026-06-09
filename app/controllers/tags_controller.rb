class TagsController < ApplicationController
  before_action :set_tag

  def update
    if @tag.update(tag_params)
      respond_to do |format|
        format.html { redirect_to settings_path(tab: :tags), notice: "Tag renommé." }
        format.turbo_stream
        format.json { render json: { status: "ok" } }
      end
    else
      respond_to do |format|
        format.html { redirect_to settings_path(tab: :tags), alert: @tag.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@tag,
                   partial: "settings/tag_row",
                   locals: { tag: @tag.reload, show_rename_form: true }),
                 status: :unprocessable_entity
        end
        format.json { render json: { errors: @tag.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @tag.destroy
    respond_to do |format|
      format.html { redirect_to settings_path(tab: :tags), notice: "Tag supprimé." }
      format.turbo_stream
      format.json { render json: { status: "ok" } }
    end
  end

  private

  def set_tag
    @tag = current_user.tags.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end
