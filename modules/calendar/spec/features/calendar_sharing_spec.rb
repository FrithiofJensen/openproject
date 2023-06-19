#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
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

require 'spec_helper'
require_relative './shared_context'

RSpec.describe 'Calendar sharing via ical', js: true do
  include_context 'with calendar full access'

  let(:user_with_sharing_permission) do
    create(:user,
           firstname: 'Bernd',
           member_in_project: project,
           member_with_permissions: %w[
             view_work_packages
             save_queries
             view_calendar
             share_calendars
           ])
  end

  let(:user_without_sharing_permission) do
    # missing share_calendars permission
    # the manage_calendars permission should not be sufficient
    # sharing via ical needs to be explicitly allowed
    create(:user,
           firstname: 'Bernd',
           member_in_project: project,
           member_with_permissions: %w[
             view_work_packages
             save_queries
             view_calendar
             manage_calendars
           ])
  end

  let(:saved_query) do
    create(:query_with_view_work_packages_calendar,
           user: user_with_sharing_permission,
           project:,
           public: false)
  end

  context 'with sufficient permissions', with_settings: { ical_enabled: true } do
    before do
      login_as user_with_sharing_permission
      calendar.visit!
    end

    context 'on not persisted calendar query' do
      # add "manage_calendars" permission to user for this context
      # in order to enable creating a new calendar on the UI.
      # this permission is not mandatory for the actual feature
      let(:user_with_sharing_permission) do
        create(:user,
               firstname: 'Bernd',
               member_in_project: project,
               member_with_permissions: %w[
                 view_work_packages
                 save_queries
                 view_calendar
                 manage_calendars
                 share_calendars
               ])
      end

      it 'shows disabled sharing menu item' do
        visit project_calendars_path(project)

        click_link "Create new calendar"

        # wait for settings button to become visible
        expect(page).to have_selector("#work-packages-settings-button")

        # click on settings button
        page.find_by_id('work-packages-settings-button').click

        # expect disabled sharing menu item
        within "#settingsDropdown" do
          # expect(page).to have_button("Subscribe to iCalendar", disabled: true) # disabled selector not working
          expect(page).to have_selector(".menu-item.inactive", text: "Subscribe to iCalendar")
          page.click_button("Subscribe to iCalendar")

          # modal should not be shown
          expect(page).not_to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
        end
      end
    end

    context 'on persisted calendar query' do
      before do
        saved_query

        visit project_calendars_path(project)

        within '#content' do
          click_link saved_query.name
        end

        loading_indicator_saveguard
      end

      it 'shows an active menu item' do
        # wait for settings button to become visible
        expect(page).to have_selector("#work-packages-settings-button")

        # click on settings button
        page.find_by_id('work-packages-settings-button').click

        # expect active sharing menu item
        within "#settingsDropdown" do
          expect(page).to have_selector(".menu-item", text: "Subscribe to iCalendar")
        end
      end

      context 'when ical sharing is disabled globally', with_settings: { ical_enabled: false } do
        it 'shows a disabled menu item' do
          # wait for settings button to become visible
          expect(page).to have_selector("#work-packages-settings-button")

          # click on settings button
          page.find_by_id('work-packages-settings-button').click

          # expect disabled sharing menu item
          within "#settingsDropdown" do
            # expect(page).to have_button("Subscribe to iCalendar", disabled: true) # disabled selector not working
            expect(page).to have_selector(".menu-item.inactive", text: "Subscribe to iCalendar")
            page.click_button("Subscribe to iCalendar")

            # modal should not be shown
            expect(page).not_to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
          end
        end
      end

      it 'shows a sharing modal' do
        open_sharing_modal

        expect(page).to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
      end

      it 'closes the sharing modal when closed by user by clicking the close button' do
        open_sharing_modal

        expect(page).to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")

        click_button "Cancel"

        expect(page).not_to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
      end

      it 'successfully requests a new tokenized iCalendar URL when a unique name is provided' do
        open_sharing_modal

        fill_in "Token name", with: "A token name"

        click_button "Copy URL"

        # implicitly testing for success -> modal is closed and fallback message is shown
        expect(page).not_to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
        expect(page).to have_content("/projects/#{saved_query.project.id}/calendars/#{saved_query.id}/ical?ical_token=")

        # explictly testing for success message is not working in test env, probably
        # due to missing clipboard permissions of the headless browser
        #
        # expect(page).to have_content("URL copied to clipboard")

        # TODO: Not able to test if the URL was actuall copied to the clipboard
        # Tried following without success
        # https://copyprogramming.com/howto/emulating-a-clipboard-copy-paste-with-selinum-capybara
      end

      it 'validates the presence of a name' do
        open_sharing_modal

        # fill_in "Token name", with: "A token name"

        click_button "Copy URL"

        # modal is still shown and error message is shown
        expect(page).to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
        expect(page).to have_content("Name is mandatory")
      end

      it 'validates the uniqueness of a name' do
        open_sharing_modal

        fill_in "Token name", with: "A token name"

        click_button "Copy URL"

        expect(page).not_to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
        expect(page).to have_content("/projects/#{saved_query.project.id}/calendars/#{saved_query.id}/ical?ical_token=")

        # do the same thing again, now expect validation error

        open_sharing_modal

        fill_in "Token name", with: "A token name" # same name for same user and same query -> not allowed

        click_button "Copy URL"

        # modal is still shown and error message is shown
        expect(page).to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
        expect(page).to have_content("Name is already in use")
      end
    end
  end

  context 'without sufficient permissions' do
    let(:saved_query) do
      create(:query_with_view_work_packages_calendar,
             user: user_without_sharing_permission,
             project:,
             public: false)
    end

    before do
      login_as user_without_sharing_permission
      calendar.visit!
    end

    context 'on persisted calendar query' do
      before do
        saved_query

        visit project_calendars_path(project)

        within '#content' do
          click_link saved_query.name
        end

        loading_indicator_saveguard
      end

      it 'shows disabled sharing menu item' do
        # wait for settings button to become visible
        expect(page).to have_selector("#work-packages-settings-button")

        # click on settings button
        page.find_by_id('work-packages-settings-button').click

        # expect disabled sharing menu item
        within "#settingsDropdown" do
          # expect(page).to have_button("Subscribe to iCalendar", disabled: true) # disabled selector not working
          expect(page).to have_selector(".menu-item.inactive", text: "Subscribe to iCalendar")
          page.click_button("Subscribe to iCalendar")

          # modal should not be shown
          expect(page).not_to have_selector('.spot-modal--header', text: "Subscribe to iCalendar")
        end
      end
    end
  end

  # helper methods

  def open_sharing_modal
    # wait for settings button to become visible
    expect(page).to have_selector("#work-packages-settings-button")

    # click on settings button
    page.find_by_id('work-packages-settings-button').click

    # expect disabled sharing menu item
    within "#settingsDropdown" do
      expect(page).to have_selector(".menu-item", text: "Subscribe to iCalendar")
      page.click_button("Subscribe to iCalendar")
    end
  end
end
