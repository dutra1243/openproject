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

require "rails_helper"

RSpec.describe Homescreen::Blocks::Projects, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:admin) { create(:admin) }

  current_user { admin }

  subject(:rendered_component) { render_inline(described_class.new) }

  context "with no favorite projects" do
    let!(:visible_project) { create(:project, name: "Visible project") }

    it "renders the favorites blank slate without project creation or newest projects" do
      expect(rendered_component).to have_css("h3", text: "Favorite projects")
      expect(rendered_component).to have_test_selector("projects-widget-empty")
      expect(rendered_component).to have_text("You have no favorite projects")
      expect(rendered_component).to have_no_link(visible_project.name)
      expect(rendered_component).to have_no_link(href: new_project_path)
      expect(rendered_component).to have_no_link("View all projects")
    end
  end

  context "with favorite projects" do
    let!(:favorite_project) { create(:project, name: "Favorite project") }
    let!(:visible_project) { create(:project, name: "Visible project") }

    before do
      create(:favorite, user: admin, favorited: favorite_project)
    end

    it "renders only favorite projects and a link to all projects" do
      expect(rendered_component).to have_css("h3", text: "Favorite projects")
      expect(rendered_component).to have_link(favorite_project.name, href: project_path(favorite_project))
      expect(rendered_component).to have_css(".op-widget-box--footer") do |footer|
        expect(footer).to have_link("View all projects", href: projects_path)
      end

      expect(rendered_component).to have_no_link(visible_project.name)
      expect(rendered_component).to have_no_link(href: new_project_path)
      expect(rendered_component).to have_no_text("Newest visible projects in this instance.")
    end
  end
end
