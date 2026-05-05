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

class Filters::Inputs::SelectWithToggleInput < Primer::Forms::Dsl::SelectInput
  attr_reader :selected_values, :filter_name

  def initialize(name:, label:, allowed_values:, selected_values:, collapse:, filter_name:, **system_arguments)
    @selected_values = Array(selected_values)
    @collapse = collapse
    @filter_name = filter_name
    super(name:, label:, **system_arguments) do |select|
      allowed_values.each { |opt_label, opt_value| select.option(label: opt_label, value: opt_value) }
    end
  end

  def collapse? = @collapse

  def to_component
    Filters::Inputs::SelectWithToggleComponent.new(input: self)
  end

  def type
    :select_with_toggle
  end
end
