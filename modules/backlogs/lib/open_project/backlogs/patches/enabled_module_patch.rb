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
  # (is_closed: true). This mirrors the form behaviour where these statuses are
  # pre-selected and disabled, so users never have to visit the settings page just
  # to get sensible defaults.
  def seed_backlogs_done_statuses
    return unless project

    mandatory_statuses = Status.where(is_closed: true)
    return if mandatory_statuses.empty?

    # Only add statuses not already present to avoid duplicate-key errors
    already_present_ids = project.done_statuses.pluck(:id)
    to_add = mandatory_statuses.where.not(id: already_present_ids)

    project.done_statuses << to_add if to_add.any?
  end
end

EnabledModule.include OpenProject::Backlogs::Patches::EnabledModulePatch
