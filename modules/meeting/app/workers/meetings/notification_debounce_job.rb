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

module Meetings
  # Debounces email notifications for meeting changes. Instead of sending emails
  # immediately for every participant addition/removal or attribute update, this
  # job waits for 1 minute of inactivity.
  # It then sends a set of emails based on the net diff between the
  # journal snapshot at the start of the debounce window and the latest journal.
  #
  # Callers use `.debounce(meeting)` to:
  # 1. Cancels any pending job for this meeting (preserving its since_journal_id)
  # 2. Schedules a new job with a fresh wait period
  #
  # When debounce_minutes == 0 the service is called synchronously (previous behavior).
  class NotificationDebounceJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_with_priority :notification

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "Meetings::NotificationDebounceJob-#{arguments.first}" }
    )

    def self.unique_key_for(meeting_id)
      "Meetings::NotificationDebounceJob-#{meeting_id}"
    end

    # +since_invited_ids+ is an explicit array of invited user IDs representing the
    # participant list BEFORE the current debounce window started. Callers that
    # know them (CreateService, DeleteService) pass it here so the
    # dispatch service can correctly diff participants even when journal aggregation
    # has overwritten the predecessor journal in-place.
    def self.debounce(meeting, since_journal_id: nil, since_invited_ids: nil)
      concurrency_key = unique_key_for(meeting.id)
      existing = GoodJob::Job.where(finished_at: nil, concurrency_key:).first
      args = preserved_job_args(existing, meeting, since_journal_id, since_invited_ids)

      GoodJob::Job.where(finished_at: nil, concurrency_key:).delete_all
      set(wait: 1.minute).perform_later(meeting.id, *args)
    end

    def perform(meeting_id, since_journal_id, since_invited_ids = nil)
      meeting = Meeting.find_by(id: meeting_id)
      return unless meeting
      return unless meeting.send_emails?

      since_journal  = Journal.find_by(id: since_journal_id)
      latest_journal = meeting.last_journal

      return if latest_journal.nil?
      return if latest_journal.id == since_journal_id

      Meetings::DispatchAggregatedNotificationsService
        .new(meeting:, since_journal:, latest_journal:, since_invited_ids:)
        .call
    end

    def self.cancel_pending(meeting)
      GoodJob::Job.where(finished_at: nil, concurrency_key: unique_key_for(meeting.id)).delete_all
    end

    # Extracts since_journal_id, since_invited_ids from the existing pending job
    # Uses the following order: previous job args > explicit caller arg > journal predecessor.
    def self.preserved_job_args(existing, meeting, since_journal_id, since_invited_ids)
      existing_journal_id, existing_invited_ids = serialized_job_args(existing)
      [
        existing_journal_id || since_journal_id || meeting.last_journal&.predecessor&.id,
        existing_invited_ids || since_invited_ids
      ]
    end

    def self.serialized_job_args(existing)
      args = existing&.serialized_params&.dig("arguments") || []
      [args[1], args[2]]
    end
  end
end
