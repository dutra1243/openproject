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

require "spec_helper"

RSpec.describe WorkPackages::Scopes::WithoutStatusConsideredClosed do
  let(:user) { create(:admin) }
  let(:open_status) { create(:status, is_closed: false) }
  let(:closed_status) { create(:status, is_closed: true) }
  let(:open_status_defined_as_done_in_project) { create(:status, is_closed: false) }
  let(:project) do
    create(:project, enabled_module_names: %w[backlogs]) do |p|
      p.done_status_ids = [closed_status.id, open_status_defined_as_done_in_project.id]
    end
  end

  current_user { user }

  subject(:unfinished) { WorkPackage.without_status_considered_closed }

  describe ".without_status_considered_closed" do
    it "returns work packages that are defined as 'not done' in the project" do
      wp_with_open_status = create(:work_package, project:, status: open_status)
      create(:work_package, project:, status: closed_status)
      create(:work_package, project:, status: open_status_defined_as_done_in_project)

      expect(unfinished).to contain_exactly(wp_with_open_status)
    end

    it "considers the 'not done' configuration of the project a work package belongs to" do
      project_where_closed_status_is_not_defined_as_done = create(:project, enabled_module_names: %w[backlogs]) do |p|
        # Note that 'closed_status' is missing here
        p.done_status_ids = [open_status_defined_as_done_in_project.id]
      end

      create(:work_package, status: closed_status, project:)
      not_quite_closed_wp = create(:work_package,
                                   status: closed_status,
                                   project: project_where_closed_status_is_not_defined_as_done)

      expect(unfinished).to contain_exactly(not_quite_closed_wp)
    end
  end
end
