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
    class TableComponent < ::TableComponent
      columns :name, :unit, :unit_plural, :current_rate, :default
      sortable_columns :name, :unit, :unit_plural
      options :fixed_date

      def initial_sort
        %i[name asc]
      end

      def headers
        [
          ["name", { caption: CostType.model_name.human }],
          ["unit", { caption: CostType.human_attribute_name(:unit) }],
          ["unit_plural", { caption: CostType.human_attribute_name(:unit_plural) }],
          ["current_rate", { caption: CostType.human_attribute_name(:current_rate) }],
          ["default", { caption: I18n.t(:caption_default) }]
        ]
      end

      def sortable?
        true
      end

      def fixed_date
        options.fetch(:fixed_date) { Date.current }
      end
    end
  end
end
