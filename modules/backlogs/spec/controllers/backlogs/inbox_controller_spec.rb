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

RSpec.describe Backlogs::InboxController do
  current_user { user }

  let(:user) { create(:admin) }
  let(:project) { create(:project) }
  let!(:work_packages) { create_list(:work_package, 5, project:) }
  let(:work_package) { create(:work_package, project:) }

  before { subject }

  shared_examples_for "checks permissions for private projects" do
    context "with a private project" do
      let(:project) { create(:private_project) }

      context "when the user is not a member" do
        let(:user) { create(:user) }

        it "responds with 404" do
          expect(response).to have_http_status :not_found
        end
      end

      context "when the user is a member with required permissions" do
        let(:user) do
          create(:user, member_with_permissions: { project => %i[manage_sprint_items view_sprints view_work_packages] })
        end

        it "responds successfully" do
          expect(response).to be_successful
        end
      end
    end
  end

  describe "GET #menu" do
    subject do
      get :menu, params: { project_id: project.id, id: work_package.id }, format: :html
    end

    shared_examples "it renders the menu" do
      it "returns deferred action menu list HTML", :aggregate_failures do
        subject
        expect(response).to have_http_status :ok
        expect(response.body).to include(I18n.t(:"js.button_open_details"))
      end

      context "when all=1 is in params" do
        subject do
          get :menu, params: { project_id: project.id, id: work_package.id, all: "1" }, format: :html
        end

        it "embeds the all query in deferred action URLs" do
          subject
          expect(response.body).to match(/all=1/)
        end
      end

      context "when the work package belongs to another project" do
        let(:other_project) { create(:project) }
        let(:work_package) { create(:work_package, project: other_project) }

        it "responds with 404" do
          expect(response).to have_http_status :not_found
        end
      end

      context "with a user lacking project permission" do
        let(:user) { create(:user) }

        it "responds with 404" do
          subject
          expect(response).to have_http_status :not_found
        end
      end
    end

    shared_examples "renders actions to move in both directions" do
      it "renders actions to move in both directions", :aggregate_failures do
        expect(response.body).to include(I18n.t(:label_sort_highest))
        expect(response.body).to include(I18n.t(:label_sort_higher))
        expect(response.body).to include(I18n.t(:label_sort_lower))
        expect(response.body).to include(I18n.t(:label_sort_lowest))
      end
    end

    shared_examples "renders only actions to move to bottom" do
      it "renders only actions to move to bottom", :aggregate_failures do
        expect(response.body).not_to include(I18n.t(:label_sort_highest))
        expect(response.body).not_to include(I18n.t(:label_sort_higher))
        expect(response.body).to include(I18n.t(:label_sort_lower))
        expect(response.body).to include(I18n.t(:label_sort_lowest))
      end
    end

    shared_examples "renders only actions to move to top" do
      it "renders only actions to move to top", :aggregate_failures do
        expect(response.body).to include(I18n.t(:label_sort_highest))
        expect(response.body).to include(I18n.t(:label_sort_higher))
        expect(response.body).not_to include(I18n.t(:label_sort_lower))
        expect(response.body).not_to include(I18n.t(:label_sort_lowest))
      end
    end

    shared_examples "renders no actions to move" do
      it "renders no actions to move", :aggregate_failures do
        expect(response.body).not_to include(I18n.t(:label_sort_highest))
        expect(response.body).not_to include(I18n.t(:label_sort_higher))
        expect(response.body).not_to include(I18n.t(:label_sort_lower))
        expect(response.body).not_to include(I18n.t(:label_sort_lowest))
      end
    end

    let!(:bucket1) { create(:backlog_bucket, project:) }
    let!(:bucket2) { create(:backlog_bucket, project:) }

    let!(:bucket1_lone_work_package) { create(:work_package, project:, backlog_bucket: bucket1) }
    let!(:bucket2_work_packages) { create_list(:work_package, 5, project:, backlog_bucket: bucket2) }

    it_behaves_like "checks permissions for private projects"

    it_behaves_like "it renders the menu"

    context "for work package at the top of inbox" do
      let(:work_package) { work_packages.first }

      it_behaves_like "renders only actions to move to bottom"
    end

    context "for work package at the bottom of inbox" do
      let(:work_package) { work_packages.last }

      it_behaves_like "renders only actions to move to top"
    end

    context "for work package in the middle of inbox" do
      let(:work_package) { work_packages.third }

      it_behaves_like "renders actions to move in both directions"
    end

    context "for a work package alone in the bucket" do
      let(:work_package) { bucket1_lone_work_package }

      it_behaves_like "renders no actions to move"
    end

    context "for work package at the top of bucket with multiple" do
      let(:work_package) { bucket2_work_packages.first }

      it_behaves_like "renders only actions to move to bottom"
    end

    context "for work package in the middle of bucket with multiple" do
      let(:work_package) { bucket2_work_packages.third }

      it_behaves_like "renders actions to move in both directions"
    end

    context "for work package at the bottom of bucket with multiple" do
      let(:work_package) { bucket2_work_packages.last }

      it_behaves_like "renders only actions to move to top"
    end
  end
end
