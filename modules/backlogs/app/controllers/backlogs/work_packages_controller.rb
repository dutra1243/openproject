# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Backlogs
  class WorkPackagesController < BaseController
    include OpTurbo::ComponentStream

    before_action :load_story

    # Deferred ActionMenu items (Primer include-fragment).
    def menu
      stories = if @story.sprint
                  @allowed_stories.where(sprint: @story.sprint)
                else
                  @allowed_stories.with_status_open.where(sprint_id: nil)
                end

      max_position = stories.maximum(:position) || 0

      open_sprints_exist = Sprint.for_project(@project)
                                 .visible
                                 .not_completed
                                 .where.not(id: @story.sprint)
                                 .exists?

      render(Backlogs::StoryMenuListComponent.new(
               story: @story,
               project: @project,
               max_position:,
               open_sprints_exist:,
               current_user:
             ),
             layout: false)
    end

    def move
      # Capture the source before the call; the service reloads @story internally via #move_after.
      source = @story.sprint || :inbox

      call = Stories::UpdateService.new(user: current_user, story: @story)
                                   .call(attributes: move_attributes_from_target, **position_attributes)

      if call.success?
        target = call.result.sprint || :inbox
        move_story_to_target_component_via_turbo_stream(source:, target:)
      else
        render_error_flash_message_via_turbo_stream(
          message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
        )
      end

      respond_with_turbo_streams(status: call.success? ? :ok : :unprocessable_entity)
    end

    def move_to_sprint_dialog
      respond_with_dialog Backlogs::MoveToSprintDialogComponent.new(
        work_package: @story,
        project: @project,
        move_action: move_project_backlogs_work_package_path(@project, @story, helpers.all_backlogs_params)
      )
    end

    def reorder
      call = Stories::UpdateService
        .new(user: current_user, story: @story)
        .call(attributes: { move_to: reorder_param })

      if call.success?
        replace_component_via_turbo_stream(call.result.sprint || :inbox)
      else
        render_error_flash_message_via_turbo_stream(
          message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
        )
      end

      respond_with_turbo_streams(status: call.success? ? :ok : :unprocessable_entity)
    end

    private

    def move_story_to_target_component_via_turbo_stream(source:, target:)
      if source != target
        flash_successful_move(from: source, to: target)
        replace_component_via_turbo_stream(source)
      end

      replace_component_via_turbo_stream(target)
    end

    def flash_successful_move(from:, to:)
      # No success message when moving from the inbox.
      if from != :inbox
        render_success_flash_message_via_turbo_stream(
          message: I18n.t(:notice_successful_move,
                          from: from.name,
                          to: to == :inbox ? I18n.t(:label_inbox) : to.name)
        )
      end
    end

    def replace_component_via_turbo_stream(container)
      component = if container == :inbox
                    inbox_component
                  else
                    sprint_component(sprint: container)
                  end

      replace_via_turbo_stream(component:, method: :morph)
    end

    def sprint_component(sprint:)
      Backlogs::SprintComponent.new(sprint:, project: @project)
    end

    def inbox_component
      inbox_work_packages = WorkPackage.backlogs_inbox_for(project: @project)
      buckets = BacklogBucket.for_project(@project)

      Backlogs::BacklogComponent.new(inbox_work_packages:, buckets:, project: @project)
    end

    def load_story
      @allowed_stories = WorkPackage.visible.where(project: @project)
      @story = @allowed_stories.find(params[:id])
    end

    def move_params
      params.require(:target_id)
      params.permit(:position, :prev_id, :target_id)
    end

    def position_attributes
      if move_params.has_key?(:prev_id)
        { prev_id: move_params[:prev_id].to_i }
      elsif move_params.has_key?(:position)
        { position: move_params[:position].to_i }
      else
        {}
      end
    end

    def reorder_param
      params.expect(:direction)
    end

    def move_attributes_from_target
      target_type, target_id = move_params[:target_id].split(":", 2)

      case target_type
      when "sprint"
        { backlog_bucket_id: nil, sprint_id: target_id }
      when "backlog_bucket"
        { backlog_bucket_id: target_id, sprint_id: nil }
      when "inbox"
        { backlog_bucket_id: nil, sprint_id: nil }
      else
        raise ArgumentError, "target_type must be one of: backlog_bucket, sprint, inbox."
      end
    end
  end
end
