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

module Projects
  class BacklogsTypesAndStatusesContract < ::ModelContract
    validate :validate_permissions
    validate :validate_done_status_ids
    validate :validate_excluded_work_package_type_ids

    def validate_model? = false

    private

    def validate_permissions
      unless user.allowed_in_project?(:select_backlog_types_and_statuses, model)
        errors.add :base, :error_unauthorized
      end
    end

    def validate_done_status_ids
      submitted_ids = model.done_status_ids.map(&:to_i)

      # All statuses are selectable, so the only faulty option here is a
      # fabricated or stale ID:
      existing_ids = Status.where(id: submitted_ids).ids
      invalid_ids = submitted_ids - existing_ids

      if invalid_ids.any?
        errors.add :done_status_ids, :invalid
        return
      end

      # Statuses defined as "closed" are mandatory and must always be included
      mandatory_ids = Status.where(is_closed: true).ids
      model.done_status_ids = (submitted_ids + mandatory_ids).uniq
    end

    def validate_excluded_work_package_type_ids
      submitted_ids = model.excluded_work_package_type_ids
      return if submitted_ids.empty?

      # Only types enabled on the project are allowed:
      project_type_ids = model.types.pluck(:id)
      invalid_ids = submitted_ids.map(&:to_i) - project_type_ids

      errors.add :excluded_work_package_type_ids, :invalid if invalid_ids.any?
    end
  end
end
