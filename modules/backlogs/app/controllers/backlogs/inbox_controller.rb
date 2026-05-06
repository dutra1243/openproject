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
  class InboxController < BaseController
    before_action :load_work_package

    # Deferred ActionMenu items (Primer include-fragment).
    def menu
      backlog_items_scope = if @work_package.backlog_bucket_id
                              @work_package.backlog_bucket.work_packages
                            else
                              WorkPackage.backlogs_inbox_for(project: @project)
                            end

      max_position = backlog_items_scope.maximum(:position) || 0
      open_sprints_exist = Sprint.for_project(@project).visible.not_completed.exists?

      render(Backlogs::InboxMenuComponent.new(
               work_package: @work_package,
               project: @project,
               max_position:,
               open_sprints_exist:,
               current_user:
             ),
             layout: false)
    end

    private

    def load_work_package
      @work_package = WorkPackage.visible.where(project: @project).find(params[:id])
    end
  end
end
