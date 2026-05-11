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

module OpenProject::Backlogs::Patches::EnabledModulePatch
  extend ActiveSupport::Concern

  included do
    after_create :seed_backlogs_done_statuses, if: -> { name == "backlogs" }
  end

  private

  # When the backlogs module is first enabled on a project, automatically populate
  # the project's done_statuses with all statuses that are globally marked as closed
  # (is_closed: true). This mirrors the form behavior where these statuses are
  # pre-selected and disabled, so users never have to visit the settings page just
  # to get sensible defaults.
  def seed_backlogs_done_statuses # rubocop:disable Metrics/AbcSize
    return unless project

    mandatory_ids = Status.where(is_closed: true).pluck(:id)
    return if mandatory_ids.empty?

    merged_ids = (project.done_statuses.reorder(nil).pluck(:id) | mandatory_ids)

    # Normalize the HABTM association explicitly by clearing and setting it:
    project.class.transaction do
      project.done_statuses = []
      project.done_statuses = Status.where(id: merged_ids)
    end
  end
end

EnabledModule.include OpenProject::Backlogs::Patches::EnabledModulePatch
