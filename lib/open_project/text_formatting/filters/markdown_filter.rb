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

module OpenProject::TextFormatting
  module Filters
    class MarkdownFilter < HTML::Pipeline::MarkdownFilter
      # Convert Markdown to HTML using CommonMarker
      def call
        render_html
      end

      private

      ##
      # Render markdown to html
      def render_html
        Commonmarker.to_html(text, options: commonmarker_options)
                    .tap(&:rstrip!)
      end

      ##
      # CommonMarker Options
      # https://github.com/gjtorikian/commonmarker#options
      def commonmarker_options
        {
          parse: { smart: false },
          extension: commonmark_extensions.map { |k| [k, true] }.to_h,
          render: {
            unsafe_: true, # option is called unsafe_ not unsafe
            github_pre_lang: true,
            hardbreaks: context[:gfm] != false
          }
        }
      end

      ##
      # Extensions to the default CommonMarker operation
      def commonmark_extensions
        context.fetch :commonmarker_extensions, %i[table strikethrough tagfilter]
      end
    end
  end
end
