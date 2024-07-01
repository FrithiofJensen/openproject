# frozen_string_literal: true

# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2010-2023 the OpenProject GmbH
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

class WorkPackages::ActivitiesTabController < ApplicationController
  include OpTurbo::ComponentStream

  before_action :find_work_package
  before_action :find_project
  before_action :find_journal, only: %i[edit cancel_edit update]
  before_action :authorize

  def index
    render(
      WorkPackages::ActivitiesTab::IndexComponent.new(
        work_package: @work_package,
        filter: params[:filter]&.to_sym || :all
      ),
      layout: false
    )
  end

  def update_filter
    filter = params[:filter]&.to_sym || :all

    update_via_turbo_stream(
      component: WorkPackages::ActivitiesTab::Journals::FilterAndSortingComponent.new(
        work_package: @work_package,
        filter:
      )
    )
    update_via_turbo_stream(
      component: WorkPackages::ActivitiesTab::Journals::IndexComponent.new(
        work_package: @work_package,
        filter:
      )
    )

    respond_with_turbo_streams
  end

  def update_streams
    generate_time_based_update_streams(params[:last_update_timestamp], params[:filter])

    respond_with_turbo_streams
  end

  def edit
    # check if allowed to edit at all
    update_via_turbo_stream(
      component: WorkPackages::ActivitiesTab::Journals::ItemComponent.new(
        journal: @journal,
        state: :edit
      )
    )

    respond_with_turbo_streams
  end

  def cancel_edit
    update_via_turbo_stream(
      component: WorkPackages::ActivitiesTab::Journals::ItemComponent.new(
        journal: @journal,
        state: :show
      )
    )

    respond_with_turbo_streams
  end

  def create
    ### taken from ActivitiesByWorkPackageAPI
    call = AddWorkPackageNoteService
      .new(user: User.current,
           work_package: @work_package)
      .call(journal_params[:notes],
            send_notifications: !(params.has_key?(:notify) && params[:notify] == "false"))
    ###

    if call.success? && call.result
      generate_time_based_update_streams(params[:last_update_timestamp], params[:filter])
    end

    # clear_form_via_turbo_stream

    respond_with_turbo_streams
  end

  def update
    call = Journals::UpdateService.new(model: @journal, user: User.current).call(
      notes: journal_params[:notes]
    )

    if call.success? && call.result
      update_via_turbo_stream(
        component: WorkPackages::ActivitiesTab::Journals::ItemComponent.new(
          journal: call.result,
          state: :show
        )
      )
    end
    # TODO: handle errors

    respond_with_turbo_streams
  end

  def update_sorting
    filter = params[:filter]&.to_sym || :all

    call = Users::UpdateService.new(user: User.current, model: User.current).call(
      pref: { comments_sorting: params[:sorting] }
    )

    if call.success?
      update_via_turbo_stream(
        component: WorkPackages::ActivitiesTab::Journals::FilterAndSortingComponent.new(
          work_package: @work_package,
          filter:
        )
      )

      update_via_turbo_stream(
        component: WorkPackages::ActivitiesTab::Journals::IndexComponent.new(
          work_package: @work_package,
          filter:
        )
      )
    end

    respond_with_turbo_streams
  end

  private

  def find_work_package
    @work_package = WorkPackage.find(params[:work_package_id])
  end

  def find_project
    @project = @work_package.project
  end

  def find_journal
    @journal = Journal.find(params[:id])
  end

  def journal_sorting
    User.current.preference&.comments_sorting || "desc"
  end

  def journal_params
    params.require(:journal).permit(:notes)
  end

  def generate_time_based_update_streams(last_update_timestamp, filter)
    # TODO: prototypical implementation
    journals = @work_package.journals

    if filter == "only_comments"
      journals = journals.where.not(notes: "")
    end

    if filter == "only_changes"
      journals = journals.where(notes: "")
    end

    journals.where("updated_at > ?", last_update_timestamp).find_each do |journal|
      update_via_turbo_stream(
        # only use the show component in order not to loose an edit state
        component: WorkPackages::ActivitiesTab::Journals::ItemComponent::Show.new(
          journal:
        )
      )
    end

    latest_journal_visible_for_user = journals.where(created_at: ..last_update_timestamp).last

    journals.where("created_at > ?", last_update_timestamp).find_each do |journal|
      append_or_prepend_latest_journal_via_turbo_stream(journal, latest_journal_visible_for_user)
    end
  end

  def append_or_prepend_latest_journal_via_turbo_stream(journal, latest_journal)
    if latest_journal.created_at.to_date == journal.created_at.to_date
      target_component = WorkPackages::ActivitiesTab::Journals::DayComponent.new(
        work_package: @work_package,
        day_as_date: journal.created_at.to_date,
        journals: [journal] # we don't need to pass all actual journals of this day as we do not really render this component
      )
      component = WorkPackages::ActivitiesTab::Journals::ItemComponent.new(
        journal:
      )
    else
      target_component = WorkPackages::ActivitiesTab::Journals::IndexComponent.new(
        work_package: @work_package
      )
      component = WorkPackages::ActivitiesTab::Journals::DayComponent.new(
        work_package: @work_package,
        day_as_date: journal.created_at.to_date,
        journals: [journal]
      )
    end
    stream_config = {
      target_component:,
      component:
    }

    # Append or prepend the new journal depending on the sorting
    if journal_sorting == "asc"
      append_via_turbo_stream(**stream_config)
    else
      prepend_via_turbo_stream(**stream_config)
    end
  end

  def update_journal_via_turbo_stream(journal)
    update_via_turbo_stream(
      component: WorkPackages::ActivitiesTab::Journals::ItemComponent.new(journal:)
    )
  end

  def clear_form_via_turbo_stream
    update_via_turbo_stream(
      component: WorkPackages::ActivitiesTab::Journals::NewComponent.new(
        work_package: @work_package
      )
    )
  end
end
