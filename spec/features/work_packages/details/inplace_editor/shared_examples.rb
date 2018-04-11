shared_examples 'an accessible inplace editor' do
  it 'triggers edit mode on click' do
    scroll_to_element(field.display_element)
    field.activate_edition
    expect(field).to be_editing
    field.cancel_by_escape
  end

  it 'triggers edit mode on RETURN key' do
    scroll_to_element(field.display_element)

    field.display_element.native.send_keys(:return)
    expect(field).to be_editing
    field.cancel_by_escape
  end

  it 'is focusable' do
    scroll_to_element(field.display_element)

    tab_index = field.display_element['tabindex']
    expect(tab_index).to_not be_nil
    expect(tab_index).to_not eq('-1')
  end
end

shared_examples 'an auth aware field' do
  context 'when is editable' do
    it_behaves_like 'an accessible inplace editor'
  end

  context 'when user is authorized' do
    it 'is editable' do
      expect(field).to be_editable
    end
  end

  context 'when user is not authorized' do
    let(:user) {
      FactoryGirl.create(
        :user,
        member_in_project: project,
        member_through_role: FactoryGirl.build(
          :role,
          permissions: [:view_work_packages]
        )
      )
    }

    it 'is not editable' do
      expect(field).not_to be_editable
    end
  end
end

shared_examples 'having a single validation point' do
  let(:other_field) { WorkPackageField.new page, :type }
  before do
    other_field.activate_edition
    field.activate_edition
    field.input_element.set ''
    field.submit_by_enter
  end

  after do
    field.cancel_by_escape
    other_field.cancel_by_escape
  end
end

shared_examples 'a required field' do
  before do
    field.activate_edition
    field.input_element.set ''
    field.submit_by_enter
  end

  after do
    field.cancel_by_escape
  end
end

shared_examples 'a cancellable field' do
  shared_examples 'cancelling properly' do
    it 'reverts to read state and keeps its focus' do
      expect(field).to_not be_editing
      field.expect_state_text(work_package.send(property_name))

      active_class_name = page.evaluate_script('document.activeElement.className')
      expect(active_class_name).to include(field.display_selector[1..-1])
    end
  end

  context 'by escape' do
    before do
      field.activate!
      sleep 1
      field.cancel_by_escape
    end

    it_behaves_like 'cancelling properly'
  end
end

shared_examples 'a previewable field' do
  before do
    skip('Markdown mode does not provide previewing') if Setting.text_formatting == 'markdown'
  end

  it 'can preview the field' do
    field.activate!

    field.input_element.set '*Highlight*'
    preview = field.field_container.find('.jstb_preview')

    # Enable preview
    preview.click
    expect(field.field_container).to have_selector('strong', text: 'Highlight')

    # Disable preview
    preview.click
    expect(field.field_container).to have_no_selector('strong')
  end
end

shared_examples 'a workpackage autocomplete field' do
  let!(:wp2) { FactoryGirl.create(:work_package, project: project, subject: 'AutoFoo') }

  before do
    skip('Markdown mode does not provide autocompleting') if Setting.text_formatting == 'markdown'
  end

  it 'autocompletes the other work package' do
    field.activate!
    field.input_element.send_keys(" ##{wp2.id}")
    expect(page).to have_selector('.atwho-view-ul li.cur', text: wp2.to_s.strip)
  end
end

shared_examples 'a principal autocomplete field' do
  let(:role) { FactoryGirl.create(:role, permissions: %i[view_work_packages edit_work_packages]) }
  let!(:user) do
    FactoryGirl.create :user,
                       member_in_project: project,
                       member_through_role: role,
                       firstname: 'John'
  end
  let!(:mentioned_user) do
    FactoryGirl.create :user,
                       member_in_project: project,
                       member_through_role: role,
                       firstname: 'Laura',
                       lastname: 'Foobar'
  end
  let!(:mentioned_group) do
    FactoryGirl.create(:group, lastname: 'Laudators').tap do |group|
      FactoryGirl.create :member,
                         principal: group,
                         project: project,
                         roles: [role]
    end
  end

  shared_examples 'principal autocomplete on field' do
    before do
      wp_page.visit!
      wp_page.ensure_page_loaded
    end

    it 'autocompletes links to user profiles' do
      field.activate!
      field.input_element.send_keys(" @lau")
      expect(page).to have_selector('.atwho-view-ul li', text: mentioned_user.name)
      expect(page).to have_selector('.atwho-view-ul li.cur', text: mentioned_group.name)
      expect(page).not_to have_selector('.atwho-view-ul li', text: user.name)

      field.input_element.send_keys(" @Laura Fo")
      expect(page).to have_selector('.atwho-view-ul li.cur', text: mentioned_user.name)
      expect(page).not_to have_selector('.atwho-view-ul li', text: mentioned_group.name)
      expect(page).not_to have_selector('.atwho-view-ul li', text: user.name)
    end
  end

  context 'in project' do
    let(:wp_page) { Pages::SplitWorkPackage.new(work_package, project) }
    it_behaves_like 'principal autocomplete on field'
  end

  context 'outside project' do
    let(:wp_page) { Pages::SplitWorkPackage.new(work_package) }
    it_behaves_like 'principal autocomplete on field'
  end
end
