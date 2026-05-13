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

require "spec_helper"

RSpec.describe Stories::UpdateService, type: :model do
  let(:user) { build_stubbed(:user) }
  let(:story) { build_stubbed(:work_package) }
  let(:instance) { described_class.new(user:, story:) }

  let(:inner_service) { instance_double(WorkPackages::UpdateService) }
  let(:inner_result) { ServiceResult.success(result: story) }

  before do
    allow(WorkPackages::UpdateService)
      .to receive(:new).with(user:, model: story)
      .and_return(inner_service)
    allow(inner_service).to receive(:call).and_return(inner_result)
  end

  describe "#call" do
    context "with neither target_id nor direction" do
      it "returns failure without delegating", :aggregate_failures do
        result = instance.call

        expect(result).to be_failure
        expect(result.message).to eq(I18n.t("backlogs.stories.update_service.missing_target"))
        expect(inner_service).not_to have_received(:call)
      end
    end

    context "with an invalid target_type" do
      it "returns failure without delegating", :aggregate_failures do
        result = instance.call(target_id: "unknown:42")

        expect(result).to be_failure
        expect(result.message).to eq(I18n.t("backlogs.stories.update_service.invalid_target_type"))
        expect(inner_service).not_to have_received(:call)
      end
    end

    context "with an invalid direction" do
      it "returns failure without delegating", :aggregate_failures do
        result = instance.call(direction: "sideways")

        expect(result).to be_failure
        expect(result.message).to eq(I18n.t("backlogs.stories.update_service.invalid_direction"))
        expect(inner_service).not_to have_received(:call)
      end
    end

    context "with direction" do
      it "delegates with move_to attribute" do
        instance.call(direction: "highest")

        expect(inner_service).to have_received(:call).with(move_to: "highest")
      end
    end

    context "with target_id: sprint" do
      it "delegates with sprint_id and nil backlog_bucket_id" do
        instance.call(target_id: "sprint:42")

        expect(inner_service).to have_received(:call).with(sprint_id: "42", backlog_bucket_id: nil)
      end
    end

    context "with target_id: backlog_bucket" do
      it "delegates with backlog_bucket_id and nil sprint_id" do
        instance.call(target_id: "backlog_bucket:99")

        expect(inner_service).to have_received(:call).with(backlog_bucket_id: "99", sprint_id: nil)
      end
    end

    context "with target_id: inbox" do
      it "delegates with nil sprint_id and nil backlog_bucket_id" do
        instance.call(target_id: "inbox")

        expect(inner_service).to have_received(:call).with(backlog_bucket_id: nil, sprint_id: nil)
      end
    end

    context "when the inner service fails" do
      let(:inner_result) { ServiceResult.failure(message: "Something went wrong") }

      it "returns the failure without calling move_after", :aggregate_failures do
        allow(story).to receive(:move_after)

        result = instance.call(target_id: "inbox")

        expect(result).to be_failure
        expect(story).not_to have_received(:move_after)
      end
    end

    context "with prev_id" do
      it "calls move_after with the integer prev_id on success" do
        allow(story).to receive(:move_after)

        instance.call(target_id: "inbox", prev_id: "5")

        expect(story).to have_received(:move_after).with(prev_id: 5)
      end
    end

    context "with position" do
      it "calls move_after with the integer position on success" do
        allow(story).to receive(:move_after)

        instance.call(target_id: "inbox", position: "3")

        expect(story).to have_received(:move_after).with(position: 3)
      end
    end

    context "with both prev_id and position" do
      it "prefers prev_id over position" do
        allow(story).to receive(:move_after)

        instance.call(target_id: "inbox", prev_id: "5", position: "3")

        expect(story).to have_received(:move_after).with(prev_id: 5)
        expect(story).not_to have_received(:move_after).with(position: 3)
      end
    end
  end
end
