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

module OpenProject
  module Common
    # A Primer BorderBox-backed list composition with optional header, items,
    # empty state, and footer.
    #
    # Use this component for compact lists that need consistent OpenProject
    # header actions, collapsible behavior, and row rendering.
    class BorderBoxListComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers

      attr_reader :container, :collapsible, :current_user, :header_id, :footer_id

      alias_method :collapsible?, :collapsible

      # Optional header row.
      #
      # @!parse
      #   # Adds the optional header row.
      #   #
      #   # @param system_arguments [Hash] forwarded to {Header}. List wiring
      #   #   arguments are supplied internally.
      #   # @return [ViewComponent::Slot]
      #   def with_header(**system_arguments, &block)
      #   end
      renders_one :header, ->(**system_arguments) {
        system_arguments[:id] = header_id
        system_arguments[:list_id] = list_id
        system_arguments[:collapsible] = collapsible?

        Header.new(**system_arguments)
      }

      # List row content.
      #
      # Use:
      #
      # - `item` for generic row content.
      # - `work_package_item` for rows backed by a work package card.
      #
      # @!parse
      #   # Adds a generic list row.
      #   #
      #   # @param system_arguments [Hash] forwarded to Primer's BorderBox row.
      #   # @return [ViewComponent::Slot]
      #   def with_item(**system_arguments, &block)
      #   end
      #
      #   # Adds a work-package list row.
      #   #
      #   # @param work_package [WorkPackage] work package rendered by the row.
      #   # @param project [Project] project context for the work package.
      #   # @param params [Hash] request params used by specialized item classes.
      #   # @param component_klass [Class] item component class to instantiate.
      #   # @param item_arguments [Hash] forwarded to the item component.
      #   # @return [ViewComponent::Slot]
      #   def with_work_package_item(
      #     work_package:,
      #     project: work_package.project,
      #     params: {},
      #     component_klass: WorkPackageItem,
      #     **item_arguments,
      #     &block
      #   )
      #   end
      renders_many :items, types: {
        item: {
          renders: ->(**system_arguments) {
            Item.new(**system_arguments)
          },
          as: :item
        },
        work_package_item: {
          renders: ->(
            work_package:,
            project: work_package.project,
            params: {},
            component_klass: WorkPackageItem,
            **item_arguments
          ) {
            component_klass.new(
              work_package:,
              project:,
              params:,
              container:,
              current_user:,
              **item_arguments
            )
          },
          as: :work_package_item
        }
      }

      # Optional empty-state content rendered when no items are present.
      #
      # @!parse
      #   # Adds empty-state content.
      #   #
      #   # @param title [String] empty-state title.
      #   # @param description [String, nil] optional supporting text.
      #   # @param icon [Symbol, nil] optional Primer icon.
      #   # @param system_arguments [Hash] forwarded to `Primer::Beta::Blankslate`.
      #   # @return [ViewComponent::Slot]
      #   def with_empty_state(title:, description: nil, icon: nil, **system_arguments)
      #   end
      renders_one :empty_state, ->(title:, description: nil, icon: nil, **system_arguments) {
        EmptyState.new(title:, description:, icon:, **system_arguments)
      }

      # Optional footer row.
      #
      # @!parse
      #   # Adds an optional footer row.
      #   #
      #   # @param system_arguments [Hash] forwarded to Primer's BorderBox
      #   #   footer. The `id` is generated internally for collapsible header
      #   #   wiring.
      #   # @return [ViewComponent::Slot]
      #   def with_footer(**system_arguments, &block)
      #   end
      renders_one :footer, ->(**system_arguments) {
        system_arguments[:id] = footer_id

        Footer.new(**system_arguments)
      }

      # @param container [String, Symbol, Class, Object] value passed to
      #   `dom_target` to derive DOM ids for the list and related controls.
      # @param collapsible [Boolean] whether the header renders a collapsible
      #   toggle. Defaults to `false`.
      # @param current_user [User] user context passed to work-package items.
      # @param system_arguments [Hash] forwarded to `Primer::Beta::BorderBox`.
      #   Pass `id:` to set the box id; related ids are derived from it.
      def initialize(container:, collapsible: false, current_user: User.current, **system_arguments)
        super()

        @container = container
        @collapsible = collapsible
        @current_user = current_user
        @system_arguments = system_arguments

        @system_arguments[:id] ||= dom_target(container)
        @system_arguments[:list_id] = dom_target(@system_arguments[:id], :list)
        @header_id = dom_target(@system_arguments[:id], :header)
        @footer_id = dom_target(@system_arguments[:id], :footer)
      end

      def before_render
        content
        configure_header!
      end

      def render?
        header? || items.any? || empty_state? || footer?
      end

      private

      def configure_header!
        return unless header?

        header.resolve_count!(items.size)
        return unless collapsible? && footer?

        header.collapsible_id = [list_id, footer_id].compact.join(" ")
      end

      def list_id
        @system_arguments[:list_id]
      end
    end
  end
end
