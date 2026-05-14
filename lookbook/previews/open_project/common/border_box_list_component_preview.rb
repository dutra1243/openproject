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
    # @logical_path OpenProject/Common
    class BorderBoxListComponentPreview < ViewComponent::Preview
      # @label Default
      # @param collapsible [Boolean] toggle
      def default(collapsible: false)
        render OpenProject::Common::BorderBoxListComponent.new(
          container: "border-box-list-preview",
          collapsible:
        ) do |list|
          list.with_header(title: "Things we're building", count: true) do |header|
            header.with_description { "There's lots to look forward to" }
            header.with_action_button do |button|
              button.with_leading_visual_icon(icon: :pencil)
              "Edit"
            end
            header.with_menu(button_aria_label: "List actions") do |menu|
              menu.with_item(label: "Configure") do |menu_item|
                menu_item.with_leading_visual_icon(icon: :gear)
              end
            end
          end

          list.with_item { "Prioritized project launch" }
          list.with_item { "Updated status reporting" }
          list.with_item { "Shared team calendar" }
          list.with_footer { "Next launch window: October" }
        end
      end

      # @label Flat scheme
      # @param collapsible [Boolean] toggle
      def flat(collapsible: false)
        render OpenProject::Common::BorderBoxListComponent.new(
          container: "border-box-list-flat-preview",
          scheme: :flat,
          collapsible:
        ) do |list|
          list.with_header(title: "Sprint backlog", count: true) do |header|
            header.with_description { "3 points remaining" }
            header.with_action_button do |button|
              button.with_leading_visual_icon(icon: :rocket)
              "Start sprint"
            end
            header.with_menu(button_aria_label: "Sprint actions") do |menu|
              menu.with_item(label: "Edit sprint") do |menu_item|
                menu_item.with_leading_visual_icon(icon: :pencil)
              end
            end
          end

          list.with_item { "User authentication stories" }
          list.with_item { "Dashboard improvements" }
          list.with_item { "API documentation" }
        end
      end

      # @label With work package items
      # @param collapsible [Boolean] toggle
      def with_work_package_items(collapsible: false)
        work_packages = WorkPackage.includes(:project).limit(2).to_a
        return preview_message("No work packages in the database.") if work_packages.empty?

        render OpenProject::Common::BorderBoxListComponent.new(
          container: "border-box-list-work-package-preview",
          collapsible:
        ) do |list|
          list.with_header(title: "Work packages", count: true)

          work_packages.each do |work_package|
            list.with_work_package_item(work_package:) do |item|
              item.with_menu(button_aria_label: "Work package actions") do |menu|
                menu.with_item(label: "Open", href: "/work_packages/#{work_package.id}") do |menu_item|
                  menu_item.with_leading_visual_icon(icon: :link)
                end
              end
            end
          end
        end
      end

      # @label Playground
      # @param collapsible [Boolean] toggle
      # @param title_tag [Symbol] select [h2, h3, h4, h5]
      # @param count [Symbol] select [inferred, hidden, explicit, zero]
      # @param count_scheme [Symbol] select [primary, secondary]
      # @param hide_zero_count toggle
      def playground(
        collapsible: false,
        title_tag: :h4,
        count: :inferred,
        count_scheme: :primary,
        hide_zero_count: true
      )
        render OpenProject::Common::BorderBoxListComponent.new(
          container: "border-box-list-playground-preview",
          collapsible:
        ) do |list|
          list.with_header(
            title: "Playground list",
            title_tag: title_tag.to_sym,
            count: preview_count(count),
            count_arguments: {
              scheme: count_scheme.to_sym,
              hide_if_zero: boolean_preview_param(hide_zero_count),
              aria: { label: "Visible list item count", live: "polite" }
            }
          ) do |header|
            header.with_description { "Advanced header options" }
          end

          list.with_item { "First item" }
          list.with_item { "Second item" }
          list.with_footer { "Footer content" }
        end
      end

      # @label Empty state
      # List with a header and an empty state (Blankslate), no items.
      # @param collapsible [Boolean] toggle
      def empty_state(collapsible: false)
        render OpenProject::Common::BorderBoxListComponent.new(
          container: "border-box-list-empty-preview",
          collapsible:
        ) do |list|
          list.with_header(title: "Empty list", count: 0)
          list.with_empty_state(
            title: "No items yet",
            description: "There is nothing to show."
          )
        end
      end

      private

      def preview_count(count)
        case count.to_sym
        when :inferred
          true
        when :hidden
          false
        when :explicit
          7
        when :zero
          0
        end
      end

      def boolean_preview_param(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def preview_message(text)
        render(Primer::Beta::Blankslate.new) do |blankslate|
          blankslate.with_heading(tag: :h4).with_content(text)
        end
      end
    end
  end
end
