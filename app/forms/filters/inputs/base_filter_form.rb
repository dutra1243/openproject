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

class Filters::Inputs::BaseFilterForm < ApplicationForm
  def initialize(filter:, additional_attributes:, active:)
    super()
    @filter = filter
    @additional_attributes = additional_attributes
    @active = active
  end

  def self.inherited(subclass)
    super
    subclass.form do |form|
      form.group(**filter_row_arguments) do |group|
        add_operator(group)
        add_operand(group)
        add_delete_button(group)
      end
    end
  end

  protected

  def add_operand(_group)
    raise SubclassResponsibilityError
  end

  def filter_row_arguments
    args = {
      layout: :horizontal,
      classes: "advanced-filters--filter",
      data: {
        "filter--filters-form-target": "filter",
        "filter-name": @filter.name,
        "filter-type": @filter.type
      }
    }
    args[:hidden] = "hidden" unless @active
    args
  end

  private

  def add_operator(group)
    selected_operator = @filter.operator || @filter.default_operator.symbol

    group.select_list(
      name: :"operator_#{@filter.name}",
      label: @filter.human_name,
      scope_name_to_model: false,
      hidden: @filter.is_a?(Queries::Filters::Shared::BooleanFilter),
      data: {
        action: "change->filter--filters-form#setValueVisibility",
        "filter--filters-form-filter-name-param": @filter.name,
        "filter--filters-form-target": "operator",
        "filter-name": @filter.name
      }
    ) do |select|
      @filter.available_operators.each do |op|
        select.option(
          label: op.human_name,
          value: op.symbol,
          selected: op.symbol == selected_operator
        )
      end
    end
  end

  def add_delete_button(group)
    group.button(
      name: :remove_filter,
      label: I18n.t("button_delete"),
      scheme: :danger,
      data: {
        action: "click->filter--filters-form#removeFilter",
        "filter--filters-form-filter-name-param": @filter.name
      }
    ) do |button|
      button.with_leading_visual_icon(icon: :trash)
    end
  end
end
