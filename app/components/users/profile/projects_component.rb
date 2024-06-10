#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2024 the OpenProject GmbH
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

module Users
  module Profile
    class ProjectsComponent < ApplicationComponent # rubocop:disable OpenProject/AddPreviewForViewComponent
      include ApplicationHelper
      include OpTurbo::Streamable
      include OpPrimer::ComponentHelpers

      def initialize(user:)
        super()

        @user = user
        # show projects based on current user visibility.
        # But don't simply concatenate the .visible scope to the memberships
        # as .memberships has an include and an order which for whatever reason
        # also gets applied to the Project.allowed_to parts concatenated by a UNION
        # and an order inside a UNION is not allowed in postgres.
        @memberships = @user.memberships
                            .where.not(project_id: nil)
                            .where(id: Member.visible(User.current))
                            .order("projects.created_at DESC")

      end

      def render?
        @memberships.any?
      end
    end
  end
end
