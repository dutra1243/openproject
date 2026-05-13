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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Admin
  module CostTypes
    module CostTypeProjects
      class NewCostTypeProjectsFormModalComponent < ApplicationComponent
        include OpTurbo::Streamable

        DIALOG_ID = "new-cost-type-projects-modal"
        DIALOG_BODY_ID = "new-cost-type-projects-modal-body"

        def initialize(cost_type_project_mapping:, cost_type:, **)
          @cost_type_project_mapping = cost_type_project_mapping
          @cost_type = cost_type
          super(@cost_type_project_mapping, **)
        end

        private

        def url
          url_helpers.admin_cost_type_projects_path(@cost_type)
        end

        def dialog_id = DIALOG_ID
        def dialog_body_id = DIALOG_BODY_ID

        attr_reader :cost_type_project_mapping, :cost_type

        def title
          I18n.t(:label_add_projects)
        end

        def cancel_button_text
          I18n.t("button_cancel")
        end

        def submit_button_text
          I18n.t("button_add")
        end
      end
    end
  end
end
