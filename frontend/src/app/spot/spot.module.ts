import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { A11yModule } from '@angular/cdk/a11y';
import { UIRouterModule } from '@uirouter/angular';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { SPOT_DOCS_ROUTES } from './spot.routes';
import { SpotCheckboxComponent } from './components/checkbox/checkbox.component';
import { SpotToggleComponent } from './components/toggle/toggle.component';
import { SpotTextFieldComponent } from './components/text-field/text-field.component';
import { SpotFilterChipComponent } from './components/filter-chip/filter-chip.component';
import { SpotDropModalComponent } from './components/drop-modal/drop-modal.component';
import { SpotTooltipComponent } from './components/tooltip/tooltip.component';
import { SpotFormFieldComponent } from './components/form-field/form-field.component';
import { SpotFormBindingDirective } from './components/form-field/form-binding.directive';
import { SpotDocsComponent } from './spot-docs.component';

@NgModule({
  imports: [
    // Routes for /spot-docs
    UIRouterModule.forChild({ states: SPOT_DOCS_ROUTES }),
    FormsModule,
    CommonModule,
  ],
  providers: [
    I18nService,
  ],
  declarations: [
    SpotDocsComponent,

    SpotCheckboxComponent,
    SpotToggleComponent,
    SpotTextFieldComponent,
    SpotFilterChipComponent,
    SpotDropModalComponent,
    SpotFormFieldComponent,
    SpotFormBindingDirective,
    SpotTooltipComponent,
  ],
  exports: [
    SpotCheckboxComponent,
    SpotToggleComponent,
    SpotTextFieldComponent,
    SpotFilterChipComponent,
    SpotDropModalComponent,
    SpotFormFieldComponent,
    SpotFormBindingDirective,
    SpotTooltipComponent,
  ],
})
export class OpSpotModule { }
