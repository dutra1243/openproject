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
  # Compute the diff between two meeting journals and sends
  # the appropriate set of emails.
  #
  # For series templates (meeting.template? == true), series schedule updates are
  # handled by RecurringMeetings::UpdateService directly (it has the full context only then).
  # This service therefore only dispatches participant-change emails for series templates and one-time meetings
  class DispatchAggregatedNotificationsService
    attr_reader :meeting, :since_journal, :latest_journal

    def initialize(meeting:, since_journal:, latest_journal:, since_invited_ids: nil)
      @meeting = meeting
      @since_journal = since_journal
      @latest_journal = latest_journal
      @since_invited_ids_override = since_invited_ids
    end

    def call
      return unless Journal::NotificationConfiguration.active? && meeting.send_emails?

      actor = latest_journal.user

      since_invited_ids = @since_invited_ids_override || invited_user_ids_from(since_journal)
      latest_invited_ids = invited_user_ids_from(latest_journal)

      added_user_ids    = latest_invited_ids - since_invited_ids
      removed_user_ids  = since_invited_ids - latest_invited_ids
      still_invited_ids = latest_invited_ids & since_invited_ids

      all_ids = (added_user_ids + removed_user_ids + still_invited_ids).uniq
      users_by_id = User.where(id: all_ids).index_by(&:id)

      added_names   = added_user_ids.filter_map { users_by_id[it]&.name }
      removed_names = removed_user_ids.filter_map { users_by_id[it]&.name }

      attribute_changes = meeting.template? ? {} : compute_attribute_changes

      added_user_ids.each   { |uid| send_invite(users_by_id[uid], actor) }
      removed_user_ids.each { |uid| send_cancellation(users_by_id[uid], actor) }

      return if attribute_changes.empty? && added_names.empty? && removed_names.empty?

      still_invited_ids.each do |uid|
        recipient = users_by_id[uid]
        next unless recipient

        send_updated(recipient, actor, attribute_changes, added_names:, removed_names:)
      end
    end

    private

    def invited_user_ids_from(journal)
      return [] unless journal

      journal.participant_journals.where(invited: true).pluck(:user_id)
    end

    def compute_attribute_changes
      return {} unless since_journal

      since_data  = since_journal.data
      latest_data = latest_journal.data
      return {} unless since_data && latest_data

      changes = {}
      %i[title location start_time duration].each do |attr|
        next unless since_data.respond_to?(attr) && latest_data.respond_to?(attr)

        old_val = since_data.send(attr)
        new_val = latest_data.send(attr)
        changes[attr] = [old_val, new_val] if old_val != new_val
      end
      changes
    end

    def send_invite(recipient, actor)
      return unless recipient

      if meeting.template?
        MeetingSeriesMailer.invited(meeting.recurring_meeting, recipient, actor).deliver_later
      else
        MeetingMailer.invited(meeting, recipient, actor).deliver_later
      end
    end

    def send_cancellation(recipient, actor)
      return unless recipient

      if meeting.template?
        MeetingMailer.cancelled_series(meeting.recurring_meeting, recipient, actor).deliver_later
      else
        MeetingMailer.cancelled(meeting, recipient, actor).deliver_later
      end
    end

    def send_updated(recipient, actor, attribute_changes, added_names: [], removed_names: [])
      if meeting.template?
        send_series_updated(recipient, actor, added_names:, removed_names:)
      else
        send_meeting_updated(recipient, actor, attribute_changes, added_names:, removed_names:)
      end
    end

    def send_series_updated(recipient, actor, added_names:, removed_names:)
      series = meeting.recurring_meeting
      MeetingSeriesMailer.updated(series, recipient, actor,
                                  changes: { old_schedule: series.full_schedule_in_words,
                                             old_location: series.location },
                                  added_participants: added_names,
                                  removed_participants: removed_names).deliver_later
    end

    def send_meeting_updated(recipient, actor, attribute_changes, added_names:, removed_names:)
      MeetingMailer.updated(meeting, recipient, actor,
                            changes: meeting_changes(attribute_changes),
                            added_participants: added_names,
                            removed_participants: removed_names).deliver_later
    end

    def meeting_changes(attribute_changes) # rubocop:disable Metrics/AbcSize
      start_time = attribute_changes[:start_time] || [meeting.start_time, meeting.start_time]
      duration   = attribute_changes[:duration]   || [meeting.duration,   meeting.duration]
      location   = attribute_changes[:location]   || [meeting.location,   meeting.location]

      { old_start: start_time[0], new_start: start_time[1],
        old_duration: duration[0], new_duration: duration[1],
        old_location: location[0], new_location: location[1] }
    end
  end
end
