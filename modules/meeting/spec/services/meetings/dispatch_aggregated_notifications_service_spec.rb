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

RSpec.describe Meetings::DispatchAggregatedNotificationsService do
  shared_let(:project) { create(:project, enabled_module_names: %i[meetings]) }
  shared_let(:actor) { create(:user, member_with_permissions: { project => %i[view_meetings edit_meetings] }) }
  shared_let(:existing_user) { create(:user, member_with_permissions: { project => %i[view_meetings] }) }
  shared_let(:new_user) { create(:user, member_with_permissions: { project => %i[view_meetings] }) }
  shared_let(:removed_user) { create(:user, member_with_permissions: { project => %i[view_meetings] }) }

  let(:fixed_start_time) { 1.day.from_now.change(usec: 0) }
  let(:since_journal) { instance_double(Journal, user: actor, data: since_data) }
  let(:latest_journal) { instance_double(Journal, user: actor, data: latest_data) }
  let(:since_data) { instance_double(Journal::MeetingJournal, title: "Old Title", location: nil, start_time: fixed_start_time, duration: 1.0) }
  let(:latest_data) { instance_double(Journal::MeetingJournal, title: "Old Title", location: nil, start_time: fixed_start_time, duration: 1.0) }

  let(:meeting) do
    create(:meeting, project:, author: actor, notify: true)
  end

  let(:since_participant_journals) { class_double(Journal::MeetingParticipantJournal) }
  let(:latest_participant_journals) { class_double(Journal::MeetingParticipantJournal) }

  before do
    allow(since_journal).to receive(:participant_journals).and_return(since_participant_journals)
    allow(latest_journal).to receive(:participant_journals).and_return(latest_participant_journals)
    allow(since_participant_journals).to receive(:where).with(invited: true).and_return(since_participant_journals)
    allow(latest_participant_journals).to receive(:where).with(invited: true).and_return(latest_participant_journals)

    allow(Journal::NotificationConfiguration).to receive(:active?).and_return(true)
  end

  subject(:service) do
    described_class.new(meeting:, since_journal:, latest_journal:).call
  end

  def stub_invited_ids(journal_double, user_ids)
    allow(journal_double).to receive(:pluck).with(:user_id).and_return(user_ids)
  end

  context "when a user is added (not previously invited)" do
    before do
      stub_invited_ids(since_participant_journals, [existing_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id, new_user.id])
    end

    it "sends invite to the newly added user" do
      expect(MeetingMailer).to receive(:invited).with(meeting, new_user, actor).and_return(double(deliver_later: nil))
      service
    end

    it "sends participant_added to the existing user" do
      allow(MeetingMailer).to receive(:invited).and_return(double(deliver_later: nil))
      expect(MeetingMailer)
        .to receive(:participant_added)
        .with(meeting, existing_user, actor, added_participants: ["#{new_user.firstname} #{new_user.lastname}"])
        .and_return(double(deliver_later: nil))
      service
    end

    it "does not send participant_added to the newly added user" do
      allow(MeetingMailer).to receive_messages(invited: double(deliver_later: nil), participant_added: double(deliver_later: nil))
      expect(MeetingMailer).not_to receive(:participant_added).with(meeting, new_user, anything, anything)
      service
    end
  end

  context "when a user is removed (was previously invited)" do
    before do
      stub_invited_ids(since_participant_journals, [existing_user.id, removed_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id])
    end

    it "sends cancellation to the removed user" do
      expect(MeetingMailer).to receive(:cancelled).with(meeting, removed_user, actor).and_return(double(deliver_later: nil))
      service
    end

    it "sends participant_removed to the still-invited user" do
      allow(MeetingMailer).to receive(:cancelled).and_return(double(deliver_later: nil))
      expect(MeetingMailer)
        .to receive(:participant_removed)
        .with(meeting, existing_user, actor, removed_participants: ["#{removed_user.firstname} #{removed_user.lastname}"])
        .and_return(double(deliver_later: nil))
      service
    end
  end

  context "when a user is added and another is removed in the same window" do
    before do
      stub_invited_ids(since_participant_journals, [existing_user.id, removed_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id, new_user.id])
      allow(MeetingMailer).to receive_messages(invited: double(deliver_later: nil),
                                               cancelled: double(deliver_later: nil),
                                               participant_added: double(deliver_later: nil),
                                               participant_removed: double(deliver_later: nil),
                                               participants_changed: double(deliver_later: nil))
    end

    it "sends a single participants_changed email to the still-invited user" do
      service
      expect(MeetingMailer).to have_received(:participants_changed)
        .with(meeting, existing_user, actor,
              added_participants: ["#{new_user.firstname} #{new_user.lastname}"],
              removed_participants: ["#{removed_user.firstname} #{removed_user.lastname}"])
    end

    it "does not send separate participant_added and participant_removed emails" do
      service
      expect(MeetingMailer).not_to have_received(:participant_added)
      expect(MeetingMailer).not_to have_received(:participant_removed)
    end
  end

  context "when the same user is added and removed within the window (net zero)" do
    before do
      stub_invited_ids(since_participant_journals, [existing_user.id, removed_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id, removed_user.id])
    end

    it "sends no emails" do
      expect(MeetingMailer).not_to receive(:invited)
      expect(MeetingMailer).not_to receive(:cancelled)
      expect(MeetingMailer).not_to receive(:participant_added)
      expect(MeetingMailer).not_to receive(:participant_removed)
      service
    end
  end

  context "when meeting attributes change" do
    let(:new_start_time) { 2.days.from_now }

    before do
      stub_invited_ids(since_participant_journals, [existing_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id])
      allow(since_data).to receive(:start_time).and_return(1.day.from_now)
      allow(latest_data).to receive(:start_time).and_return(new_start_time)
    end

    it "sends updated email to the still-invited user" do
      expect(MeetingMailer)
        .to receive(:updated)
        .with(meeting, existing_user, actor, hash_including(changes: hash_including(:old_start, :new_start)))
        .and_return(double(deliver_later: nil))
      service
    end
  end

  context "when nothing changes" do
    before do
      stub_invited_ids(since_participant_journals, [existing_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id])
    end

    it "sends no emails" do
      expect(MeetingMailer).not_to receive(:invited)
      expect(MeetingMailer).not_to receive(:cancelled)
      expect(MeetingMailer).not_to receive(:updated)
      expect(MeetingMailer).not_to receive(:participant_added)
      expect(MeetingMailer).not_to receive(:participant_removed)
      service
    end
  end

  context "when since_journal is nil" do
    let(:since_journal) { nil }

    before do
      stub_invited_ids(latest_participant_journals, [new_user.id])
    end

    it "treats all latest participants as newly added" do
      expect(MeetingMailer).to receive(:invited).with(meeting, new_user, actor).and_return(double(deliver_later: nil))
      service
    end
  end

  context "when since_invited_ids is provided explicitly (journal aggregation override)" do
    subject(:service) do
      described_class.new(
        meeting:,
        since_journal: nil,
        latest_journal:,
        since_invited_ids: [existing_user.id]
      ).call
    end

    before do
      stub_invited_ids(latest_participant_journals, [existing_user.id, new_user.id])
      allow(MeetingMailer).to receive_messages(invited: double(deliver_later: nil), participant_added: double(deliver_later: nil))
    end

    it "sends invite only to the newly added user (not the existing one)" do
      service
      expect(MeetingMailer).to have_received(:invited).with(meeting, new_user, actor)
      expect(MeetingMailer).not_to have_received(:invited).with(meeting, existing_user, anything)
    end

    it "sends participant_added to the existing user" do
      service
      expect(MeetingMailer)
        .to have_received(:participant_added)
        .with(meeting, existing_user, actor, added_participants: ["#{new_user.firstname} #{new_user.lastname}"])
    end
  end

  context "when meeting is a series template" do
    let(:recurring_meeting) { create(:recurring_meeting, project:, author: actor) }
    let(:meeting) { recurring_meeting.template }

    before do
      allow(meeting).to receive(:send_emails?).and_return(true)
      stub_invited_ids(since_participant_journals, [existing_user.id])
      stub_invited_ids(latest_participant_journals, [existing_user.id, new_user.id])
    end

    it "sends series invite via MeetingSeriesMailer" do
      expect(MeetingSeriesMailer)
        .to receive(:invited)
        .with(recurring_meeting, new_user, actor)
        .and_return(double(deliver_later: nil))
      service
    end

    it "sends participant_added via MeetingSeriesMailer" do
      allow(MeetingSeriesMailer).to receive(:invited).and_return(double(deliver_later: nil))
      expect(MeetingSeriesMailer)
        .to receive(:participant_added)
        .with(recurring_meeting, existing_user, actor, added_participants: anything)
        .and_return(double(deliver_later: nil))
      service
    end

    it "does not send updated even when attributes changed" do
      allow(MeetingSeriesMailer).to receive_messages(invited: double(deliver_later: nil),
                                                     participant_added: double(deliver_later: nil))
      expect(MeetingSeriesMailer).not_to receive(:updated)
      service
    end
  end

  context "when Journal::NotificationConfiguration is inactive" do
    before do
      allow(Journal::NotificationConfiguration).to receive(:active?).and_return(false)
    end

    it "sends no emails" do
      expect(MeetingMailer).not_to receive(:invited)
      service
    end
  end

  context "when meeting cannot send emails" do
    before do
      allow(meeting).to receive(:send_emails?).and_return(false)
    end

    it "sends no emails" do
      expect(MeetingMailer).not_to receive(:invited)
      service
    end
  end
end
