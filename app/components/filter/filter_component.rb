# frozen_string_literal: true

# -- copyright
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
# ++
module Filter
  class FilterComponent < ApplicationComponent
    TURBO_FRAME_ID = "filter_component"

    options :query
    # The path used for fetching the filter section lazily from the backend upon opening it.
    # If none is provided, the filters are rendered right away.
    options lazy_loaded_path: false
    options initially_expanded: false

    def inputs(form)
      filter_forms = map_filter do |filter, active, additional_attributes|
        filter_form_class(filter, additional_attributes).new(form, filter:, additional_attributes:, active:)
      end

      filter_forms << Filters::Inputs::AddFilterForm.new(
        form,
        allowed_filters:,
        active_filter_names: query.filters.map(&:name)
      )
    end

    # Maps over all filters (active and inactive).
    # In case a filter is active, the active one will be preferred over the inactive one.
    def map_filter
      allowed_filters.map do |allowed_filter|
        active_filter = query.find_active_filter(allowed_filter.name)
        filter = active_filter || allowed_filter

        yield filter, active_filter.present?, additional_filter_attributes(filter)
      end
    end

    def allowed_filters
      query.available_advanced_filters
    end

    def lazy_loaded? = !!lazy_loaded_path

    def initially_expanded? = initially_expanded

    def turbo_requests? = false

    def skeleton_height
      # This is an approximation.
      # * 100 for the padding and the filter selection
      # * 40 per filter and their bottom margin. But the height of the filters vary unfortunately.
      "#{100 + (query.filters.count * 40)}px"
    end

    def filter_classes
      "op-filters-form op-filters-form_top-margin #{'-expanded' if initially_expanded?}"
    end

    def lazy_turbo_frame_src
      public_send(lazy_loaded_path, **params.permit(:filters, :columns, :sortBy, :id, :query_id))
    end

    protected

    # With this method we can pass additional options for each type of filter into the frontend. This is especially
    # useful when we want to pass options for the autocompleter components.
    #
    # When the method is overwritten in a subclass, the subclass should call super(filter) to get the default attributes.
    #
    # @param filter [QueryFilter] the filter for which we want to pass additional attributes
    # @return [Hash] the additional attributes for the filter, yielded in map_filter
    def additional_filter_attributes(filter)
      case filter
      when Queries::Filters::Shared::ProjectFilter::Required,
           Queries::Filters::Shared::ProjectFilter::Optional
        { autocomplete_options: project_autocomplete_options }
      when Queries::Filters::Shared::CustomFields::User
        { autocomplete_options: user_autocomplete_options }
      when Queries::Filters::Shared::CustomFields::ListOptional
        { autocomplete_options: custom_field_list_autocomplete_options(filter) }
      when Queries::Filters::Shared::CustomFields::Hierarchy
        { autocomplete_options: custom_field_hierarchy_autocomplete_options(filter) }
      when Queries::Projects::Filters::ProjectStatusFilter,
           Queries::Projects::Filters::TypeFilter
        { autocomplete_options: list_autocomplete_options(filter) }
      else
        {}
      end
    end

    def filter_form_class(filter, additional_attributes)
      if filter.is_a?(Queries::Filters::Shared::BooleanFilter)
        Filters::Inputs::BooleanForm
      elsif additional_attributes.key?(:autocomplete_options)
        Filters::Inputs::AutocompleteForm
      elsif filter.type.in? %i[list list_optional list_all]
        Filters::Inputs::ListForm
      elsif filter.type.in? %i[datetime_past date]
        Filters::Inputs::DateForm
      else
        Filters::Inputs::TextForm
      end
    end

    def custom_field_list_autocomplete_options(filter)
      all_items = custom_field_allowed_items(filter)
      selected = filter.values
      options = { items: all_items }
      options[:groupBy] = "project_name" if filter.custom_field.version?
      autocomplete_options.merge(options).merge(model: all_items.select { |item| selected.include?(item[:id]) })
    end

    def custom_field_allowed_items(filter)
      if filter.custom_field.version?
        filter.allowed_values.map { |name, id, project_name| { name:, id:, project_name: } }
      else
        filter.allowed_values.map { |name, id| { name:, id: } }
      end
    end

    def custom_field_hierarchy_autocomplete_options(filter)
      items = filter.allowed_values.map do |name, id|
        path = name.split(" / ")
        { name: path.last, id:, depth: path.length - 1 }
      end
      selected = filter.values

      autocomplete_options.merge({ items: }).merge(model: items.select { |item| selected.include?(item[:id]) })
    end

    def list_autocomplete_options(filter)
      all_items = filter.allowed_values.map { |name, id| { name:, id: } }
      selected = filter.values
      autocomplete_options.merge(
        items: all_items,
        model: all_items.select { |item| selected.include?(item[:id]) }
      )
    end

    def autocomplete_options
      {
        component: "opce-autocompleter",
        bindValue: "id",
        bindLabel: "name",
        hideSelected: true
      }
    end

    def project_autocomplete_options
      {
        component: "opce-project-autocompleter",
        resource: "projects",
        filters: [
          { name: "active", operator: "=", values: ["t"] }
        ]
      }
    end

    def user_autocomplete_options
      {
        component: "opce-user-autocompleter",
        hideSelected: true,
        defaultData: false,
        placeholder: I18n.t(:label_user_search),
        resource: "principals",
        url: ::API::V3::Utilities::PathHelper::ApiV3Path.principals,
        filters: [
          { name: "status", operator: "!", values: [Principal.statuses["locked"].to_s] }
        ],
        searchKey: "any_name_attribute",
        focusDirectly: false
      }
    end
  end
end
