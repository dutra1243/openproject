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

      still_invited_ids.each do |uid|
        recipient = users_by_id[uid]
        next unless recipient

        send_updated(recipient, actor, attribute_changes) if attribute_changes.any?

        if added_names.any? && removed_names.any?
          send_participants_changed(recipient, actor, added_names, removed_names)
        elsif added_names.any?
          send_participant_added(recipient, actor, added_names)
        elsif removed_names.any?
          send_participant_removed(recipient, actor, removed_names)
        end
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

    def send_updated(recipient, actor, changes)
      MeetingMailer.updated(meeting, recipient, actor,
                            changes: {
                              old_start: changes.dig(:start_time, 0) || meeting.start_time,
                              new_start: changes.dig(:start_time, 1) || meeting.start_time,
                              old_duration: changes.dig(:duration, 0) || meeting.duration,
                              new_duration: changes.dig(:duration, 1) || meeting.duration,
                              old_location: changes.dig(:location, 0) || meeting.location,
                              new_location: changes.dig(:location, 1) || meeting.location
                            }).deliver_later
    end

    def send_participant_added(recipient, actor, added_names)
      if meeting.template?
        MeetingSeriesMailer.participant_added(meeting.recurring_meeting, recipient, actor,
                                              added_participants: added_names).deliver_later
      else
        MeetingMailer.participant_added(meeting, recipient, actor,
                                        added_participants: added_names).deliver_later
      end
    end

    def send_participant_removed(recipient, actor, removed_names)
      if meeting.template?
        MeetingSeriesMailer.participant_removed(meeting.recurring_meeting, recipient, actor,
                                                removed_participants: removed_names).deliver_later
      else
        MeetingMailer.participant_removed(meeting, recipient, actor,
                                          removed_participants: removed_names).deliver_later
      end
    end

    def send_participants_changed(recipient, actor, added_names, removed_names)
      if meeting.template?
        MeetingSeriesMailer.participants_changed(meeting.recurring_meeting, recipient, actor,
                                                 added_participants: added_names,
                                                 removed_participants: removed_names).deliver_later
      else
        MeetingMailer.participants_changed(meeting, recipient, actor,
                                           added_participants: added_names,
                                           removed_participants: removed_names).deliver_later
      end
    end
  end
end
