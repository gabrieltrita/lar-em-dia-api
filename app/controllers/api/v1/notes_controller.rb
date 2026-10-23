module Api
  module V1
    class NotesController < ApplicationController
      include Paginatable

      before_action :set_note, only: %i[show update destroy]

      def index
        authorize Note
        pagy, notes = pagy(policy_scope(Note).recent)
        render json: { data: NoteBlueprint.render_as_hash(notes), meta: pagination_meta(pagy) }
      end

      def show
        render json: { data: NoteBlueprint.render_as_hash(@note) }
      end

      def create
        note = current_user.notes.new(note_params)
        authorize note

        if note.save
          render json: { data: NoteBlueprint.render_as_hash(note) }, status: :created
        else
          render_validation_errors(note)
        end
      end

      def update
        if @note.update(note_params)
          render json: { data: NoteBlueprint.render_as_hash(@note) }
        else
          render_validation_errors(@note)
        end
      end

      def destroy
        @note.destroy!
        head :no_content
      end

      private

      def set_note
        @note = policy_scope(Note).find(params[:id])
        authorize @note
      end

      def note_params
        params.permit(:title, :body)
      end
    end
  end
end
