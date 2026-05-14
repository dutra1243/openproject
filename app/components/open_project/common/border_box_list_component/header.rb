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

module OpenProject
  module Common
    class BorderBoxListComponent
      # Structured header for {BorderBoxListComponent}.
      #
      # This component is part of {BorderBoxListComponent} and should not be
      # used as a standalone component.
      #
      # The header renders through `Primer::Beta::BorderBox#with_header` and
      # wraps the supplied title, count, description, actions, and menu in an
      # `Primer::OpenProject::BorderBox::CollapsibleHeader`.
      class Header < ApplicationComponent
        include OpPrimer::ComponentHelpers
        include Primer::AttributesHelper
        include HasMenu

        DEFAULT_ACTION_SCHEME = :default

        DEFAULT_COUNT_ARGUMENTS = {
          scheme: :primary,
          round: true,
          limit: 1_000,
          hide_if_zero: true
        }.freeze

        # @!parse
        #   # Adds secondary content below the header title.
        #   #
        #   # @return [ViewComponent::Slot]
        #   def with_description(&block)
        #   end
        renders_one :description

        # @!parse
        #   # Adds a button to the header actions area.
        #   #
        #   # @param system_arguments [Hash] forwarded to `Primer::Beta::Button`.
        #   # @return [ViewComponent::Slot]
        #   def with_action_button(**system_arguments, &block)
        #   end
        renders_many :actions, types: {
          button: ->(scheme: DEFAULT_ACTION_SCHEME, **system_arguments) do
            Primer::Beta::Button.new(scheme:, **system_arguments)
          end
        }

        attr_reader :title,
                    :count,
                    :count_label,
                    :count_arguments,
                    :title_tag,
                    :list_id,
                    :collapsed,
                    :collapsible

        attr_writer :collapsible_id

        # @param title [String] header title.
        # @param count [Integer, Boolean, nil] count badge behavior. Pass
        #   `nil` or `false` to hide it, `true` to infer the rendered item
        #   count, or an integer to render an explicit value.
        # @param count_label [String, nil] accessible label for the counter
        #   badge. Defaults to `I18n.t(:label_x_items, count:)` when a count
        #   is rendered. Pass an explicit string to override.
        # @param count_arguments [Hash] forwarded to `Primer::Beta::Counter`.
        #   Values are merged over the default counter arguments.
        # @param title_tag [Symbol] tag used for the title heading.
        # @param list_id [String, nil] id of the collapsible list body.
        # @param collapsed [Boolean] whether the collapsible header starts closed.
        # @param collapsible [Boolean] whether the header renders a collapsible
        #   toggle. Defaults to `true`. Pass `false` to render a plain title
        #   without a toggle button.
        # @param system_arguments [Hash] forwarded to `Primer::Beta::BorderBox#with_header`.
        def initialize(
          title:,
          count: nil,
          count_label: nil,
          count_arguments: {},
          title_tag: :h4,
          list_id: nil,
          collapsed: false,
          collapsible: true,
          **system_arguments
        )
          super()

          @title = title
          @count = count
          @count_label = count_label
          @count_arguments = count_arguments
          @title_tag = title_tag
          @list_id = list_id
          @collapsible_id = list_id
          @collapsed = collapsed
          @collapsible = collapsible
          @system_arguments = system_arguments
        end

        # @return [Boolean] whether a collapsible toggle should be rendered.
        def collapsible?
          collapsible
        end

        # Resolves inferred counts after the list slots have been captured.
        #
        # @param item_count [Integer] number of rendered item slots.
        # @return [void]
        def resolve_count!(item_count)
          @count = item_count if count == true
          @count_label ||= I18n.t(:label_x_items, count: @count) if render_count?
        end

        # @return [Hash] arguments forwarded to `Primer::Beta::BorderBox#with_header`.
        def row_args
          @system_arguments.deep_dup
        end

        # @return [Boolean] whether a counter should be rendered.
        def render_count?
          !count.nil? && count != false
        end

        # @return [Hash] merged arguments forwarded to `Primer::Beta::Counter`.
        def counter_arguments
          merged = DEFAULT_COUNT_ARGUMENTS.merge(count_arguments).merge(count:)
          merged[:aria] = merge_aria(
            merged,
            { aria: { label: count_label, live: "polite" } }
          )
          merged
        end

        # @return [String, nil] ids controlled by the collapsible header.
        def collapsible_id
          @collapsible_id.presence
        end

        private

        def default_menu_id
          list_id ? "#{list_id}_menu" : super
        end
      end
    end
  end
end
