/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 *
 */

import { Controller } from '@hotwired/stimulus';
import { renderStreamMessage } from '@hotwired/turbo';
import { debounce } from 'lodash';
import {
  hideElement,
  showElement,
} from 'core-app/shared/helpers/dom-helpers';
import { PrimerMultiInputElement } from '@primer/view-components/app/lib/primer/forms/primer_multi_input';

interface PrimerTextFieldElement extends HTMLElement {
  inputElement:HTMLInputElement;
}

interface InternalFilterValue {
  name:string;
  operator:string;
  value:string[];
}

type FilterFunc<T> = (_value:T) => boolean;

export default class FiltersFormController extends Controller {
  static targets = [
    'filterFormToggle',
    'filterForm',
    'simpleFilter',
    'filter',
    'addFilterSelect',
    'operator',
    'filterValueContainer',
    'filterValueSelect',
    'days',
    'singleDay',
    'dateRange',
    'simpleValue',
  ];

  declare readonly filterFormToggleTarget:HTMLButtonElement;
  declare readonly filterFormTarget:HTMLFormElement;
  declare readonly simpleFilterTargets:HTMLElement[];
  declare readonly filterTargets:HTMLElement[];
  declare readonly addFilterSelectTarget:HTMLSelectElement;
  declare readonly operatorTargets:HTMLSelectElement[];
  declare readonly filterValueContainerTargets:HTMLElement[];
  declare readonly filterValueSelectTargets:HTMLSelectElement[];
  declare readonly daysTargets:HTMLInputElement[];
  declare readonly singleDayTargets:HTMLInputElement[];
  declare readonly dateRangeTargets:HTMLInputElement[];
  declare readonly simpleValueTargets:HTMLInputElement[];

  declare readonly hasFilterFormToggleTarget:boolean;

  static values = {
    displayFilters: { type: Boolean, default: false },
    outputFormat: { type: String, default: 'params' },
    performTurboRequests: { type: Boolean, default: false },
    clearButtonId: String,
    urlPathName: String,
  };

  declare displayFiltersValue:boolean;
  declare outputFormatValue:string;
  declare performTurboRequestsValue:boolean;
  declare readonly clearButtonIdValue:string;
  declare urlPathNameValue:string;
  declare hasFilterFormTarget:boolean;

  private formLoadedResolver:(() => void)|null = () => null;

  filterFormLoaded = new Promise<void>((resolve) => {
    this.formLoadedResolver = resolve;
  });

  private boundListener:() => void;

  initialize() {
    // Initialize runs anytime an element with a controller connected to the DOM for the first time
    this.boundListener = debounce(this.sendForm.bind(this), 300);
  }

  connect() {
    const clearButton = document.getElementById(this.clearButtonIdValue);
    clearButton?.addEventListener('click', (event:MouseEvent) => this.clearInputWithButton(event));
  }

  disconnect() {
    const clearButton = document.getElementById(this.clearButtonIdValue);
    clearButton?.removeEventListener('click', (event:MouseEvent) => this.clearInputWithButton(event));
  }

  addFilterSelectTargetConnected() {
    // This is used as an indicator that the filter form is loaded. Other targets could have been used
    // as well.
    if (this.formLoadedResolver) {
      this.formLoadedResolver();
      this.formLoadedResolver = null;
    }
  }

  // Register and deregister change/input listeners on input elements to reload the page's frames on user input.
  // Using the target's methods rather than the shorter version in the controllers connect and disconnect function
  // as the filters themselves might be loaded later. If that is the case, they would not be known on connect.
  simpleValueTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
  }

  operatorTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
  }

  filterValueContainerTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
    const filterName = target.getAttribute('data-filter-name');
    if (filterName) {
      const operator = this.findTargetByName(filterName, this.operatorTargets);
      if (operator && this.noValueOperators.includes(operator.value)) {
        target.setAttribute('hidden', '');
      }
    }
  }

  filterValueSelectTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
  }

  daysTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
  }

  singleDayTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
    this.registerAngularPickerWithMultiInput(target, 'opce-basic-single-date-picker');
  }

  dateRangeTargetConnected(target:HTMLElement) {
    this.addChangeListener(target);
    this.registerAngularPickerWithMultiInput(target, 'opce-range-date-picker');
  }

  // angular_component_tag serialises @Input() bindings as JSON in data-* attributes, so the
  // Angular date picker wrapper's data-name holds a JSON-encoded value that primer-multi-input
  // cannot use to identify its child fields.  date_picker.html.erb therefore also sets
  // data-multi-input-name as a plain string with the intended field name.
  // This method is called when the Stimulus target connects, i.e. after Angular has already
  // bootstrapped the component and consumed its data-* attributes, so we can safely overwrite
  // data-name with the plain string from data-multi-input-name without interfering with Angular.
  // primer-multi-input.activateField() then uses data-name to show/hide the correct picker
  // when the filter operator changes.
  private registerAngularPickerWithMultiInput(target:HTMLElement, tagName:string) {
    const wrapper = target.closest<HTMLElement>(tagName);
    if (wrapper?.closest('primer-multi-input')) {
      const multiInputName = wrapper.getAttribute('data-multi-input-name');
      if (multiInputName) {
        wrapper.setAttribute('data-name', multiInputName);
      }
    }
  }

  simpleValueTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  operatorTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  filterValueContainerTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  filterValueSelectTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  daysTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  singleDayTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  dateRangeTargetDisconnected(target:HTMLElement) {
    this.removeChangeListener(target);
  }

  filterFormTargetConnected()  {
    // Didn't really change, but we need to ensure that the visibility of the target is correct.
    // This is caused by there first being a skeleton form, which allows the user to already
    // toggle the visibility.
    this.displayFiltersValueChanged();
  }


  toggleDisplayFilters() {
    this.displayFiltersValue = !this.displayFiltersValue;
  }

  showDisplayFilters() {
    this.displayFiltersValue = true;
  }

  displayFiltersValueChanged() {
    if (this.hasFilterFormToggleTarget){
      this.toggleButtonActive();
      this.toggleFilterFormVisible();
    }
  }

  toggleButtonActive() {
    if (this.displayFiltersValue) {
      this.filterFormToggleTarget.setAttribute('aria-pressed', 'true');
    } else {
      this.filterFormToggleTarget.removeAttribute('aria-pressed');
    }
  }

  toggleFilterFormVisible() {
    if (this.hasFilterFormTarget) {
      this.filterFormTarget.classList.toggle('-expanded', this.displayFiltersValue);
    }
  }

  toggleMultiSelect({ params: { filterName } }:{ params:{ filterName:string } }) {
    const valueContainer = this.findTargetByName(filterName, this.filterValueContainerTargets);
    const singleSelect = this.findTargetByName<HTMLSelectElement>(filterName, this.filterValueSelectTargets, (s) => !s.multiple);
    const multiSelect = this.findTargetByName<HTMLSelectElement>(filterName, this.filterValueSelectTargets, (s) => s.multiple);
    const multiInput = valueContainer?.querySelector<PrimerMultiInputElement>('primer-multi-input');

    if (valueContainer && singleSelect && multiSelect && multiInput) {
      const isMultiMode = valueContainer.dataset.multiValue === 'true';

      if (isMultiMode) {
        this.setSelectOptions(singleSelect, this.getValueToSelect(multiSelect));
        multiInput.activateField('single');
      } else {
        this.setSelectOptions(multiSelect, this.getValueToSelect(singleSelect));
        multiInput.activateField('multi');
      }

      valueContainer.dataset.multiValue = isMultiMode ? 'false' : 'true';
    }
  }

  private addChangeListener(target:HTMLElement) {
    if (!this.performTurboRequestsValue) { return; }

    if (target instanceof HTMLInputElement) {
      target.addEventListener('input', this.boundListener);
    } else {
      target.addEventListener('change', this.boundListener);
    }
  }

  private removeChangeListener(target:HTMLElement) {
    if (!this.performTurboRequestsValue) { return; }

    if (target instanceof HTMLInputElement) {
      target.removeEventListener('input', this.boundListener);
    } else {
      target.removeEventListener('change', this.boundListener);
    }
  }

  private getValueToSelect(selectElement:HTMLSelectElement) {
    return selectElement.selectedOptions[0]?.value;
  }

  private setSelectOptions(selectElement:HTMLSelectElement, selectedValue:string) {
    Array.from(selectElement.options).forEach((option) => {
      option.selected = option.value === selectedValue;
    });
  }

  addFilter(event:Event) {
    const filterName = (event.target as HTMLSelectElement).value;
    this.addFilterByName(filterName);
  }

  addFilterByName(filterName:string) {
    const selectedFilter = this.findTargetByName(filterName, this.filterTargets);
    if (selectedFilter) {
      selectedFilter.removeAttribute('hidden');
    }
    this.addFilterSelectTarget.selectedOptions[0].disabled = true;
    this.addFilterSelectTarget.selectedIndex = 0;

    this.focusFilterValueIfPossible(selectedFilter);

    if (this.performTurboRequestsValue) {
      this.sendForm();
    }
  }

  // Takes an Element and tries to find the next input or select child element. This should be the filter value.
  // If found, it will be focused.
  focusFilterValueIfPossible(element:undefined|HTMLElement) {
    if (!element) return;

    // Try different selectors for various filter styles. The order is important as some selectors match unwanted
    // hidden fields when used too early in the chain.
    const selectors = [
      '.advanced-filters--filter-value ng-select input',
      '.advanced-filters--filter-value input',
      '.advanced-filters--filter-value select',
    ];

    selectors.some((selector) => {
      const target = element.querySelector<HTMLElement>(selector);

      if (target) {
        window.setTimeout(() => {
          target.focus();

          // We have found and focused our element, abort the iteration.
          return true;
        }, 250);
      }

      return false;
    });
  }

  removeFilter({ params: { filterName } }:{ params:{ filterName:string } }) {
    const filterToRemove = this.findTargetByName(filterName, this.filterTargets);
    filterToRemove?.setAttribute('hidden', '');

    const selectOptions = Array.from(this.addFilterSelectTarget.options);
    const removedFilterOption = selectOptions.find((option) => option.value === filterName);
    removedFilterOption?.removeAttribute('disabled');

    if (this.performTurboRequestsValue) {
      this.sendForm();
    }
  }

  clearInputWithButton(event:MouseEvent) {
    // Primer does not trigger an input event when clearing the value of the input field unless
    // it is focused. This handler will find the sibling input of the clear button inside the
    // PrimerTextField and triggers the input in order to notify the auto-reloading filter mechanism.
    const element = event.currentTarget as HTMLElement;
    const primerTextField = element.closest<PrimerTextFieldElement>('primer-text-field')!;
    const inputElement = primerTextField.inputElement;

    const inputEvent = new Event('input', {
      bubbles: true,
      cancelable: true,
    });
    inputElement.dispatchEvent(inputEvent);
  }

  private readonly noValueOperators = ['*', '!*', 't', 'w'];
  private readonly daysOperators = ['>t-', '<t-', 't-', '<t+', '>t+', 't+'];
  private readonly onDateOperator = '=d';
  private readonly betweenDatesOperator = '<>d';

  setValueVisibility({ target, params: { filterName } }:{ target:HTMLSelectElement, params:{ filterName:string } }) {
    const selectedOperator = target.value;
    const valueContainer = this.findTargetByName(filterName, this.filterValueContainerTargets);
    if (valueContainer) {
      if (this.noValueOperators.includes(selectedOperator)) {
        valueContainer.setAttribute('hidden', '');
      } else {
        valueContainer.removeAttribute('hidden');
      }

      const multiInput = valueContainer.querySelector<PrimerMultiInputElement>('primer-multi-input');
      if (this.daysOperators.includes(selectedOperator)) {
        multiInput?.activateField('days');
      } else if (selectedOperator === this.onDateOperator) {
        multiInput?.activateField('singleDay');
      } else if (selectedOperator === this.betweenDatesOperator) {
        multiInput?.activateField('dateRange');
      }
    }
  }

  autocompleteSendForm() {
    if (this.performTurboRequestsValue) {
      this.sendForm();
    }
  }

  sendForm() {
    const params = new URLSearchParams(window.location.search);
    const newFilters = this.buildFiltersParam(this.parseFilters());

    if (newFilters === params.get('filters')) {
      // Some fields may be triggered via the input event and the change event too.
      // This early return will prevent firing request when the filter params are not changed.
      return;
    }

    // Remove the page parameter when changing filters, so that pagination resets
    params.delete('page');
    params.set('filters', newFilters);
    const loadingIndicator = document.querySelector<HTMLElement>('#global-loading-indicator')!;
    showElement(loadingIndicator);

    const pathName = this.urlPathNameValue || window.location.pathname;
    const url = `${pathName}?${params.toString()}`;

    if (this.performTurboRequestsValue) {
      fetch(url, {
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
        },
      })
        .then((response:Response) => response.text())
        .then((html:string) => {
          renderStreamMessage(html);
          hideElement(loadingIndicator);
        })
        .catch((error:Error) => {
          console.error('Error:', error);
          hideElement(loadingIndicator);
        });
    } else {
      window.location.href = url;
    }
  }

  private parseFilters():InternalFilterValue[] {
    const filters:InternalFilterValue[] = [];
    filters.push(...this.parseSimpleFilters());
    filters.push(...this.parseAdvancedFilters());
    return filters;
  }

  private parseSimpleFilters():InternalFilterValue[] {
    const simpleFilters = this.simpleFilterTargets;
    const filters:InternalFilterValue[] = [];

    simpleFilters.forEach((filter) => {
      const name = filter.getAttribute('data-filter-name');
      const type = filter.getAttribute('data-filter-type');
      const operator = filter.getAttribute('data-filter-operator');
      if (name && type && operator) {
        const value = this.parseFilterValue(filter, name, type, operator) as string[]|null;

        if (value) {
          filters.push({ name, operator, value });
        }
      }
    });
    return filters;
  }

  private parseAdvancedFilters():InternalFilterValue[] {
    const advancedFilters = this.filterTargets.filter((filter) => !filter.hasAttribute('hidden'));
    const filters:InternalFilterValue[] = [];

    advancedFilters.forEach((filter) => {
      const filterName = filter.getAttribute('data-filter-name')!;
      const filterType = filter.getAttribute('data-filter-type');
      const parsedOperator = this.findTargetByName(filterName, this.operatorTargets)?.value;
      const valueContainer = this.findTargetByName(filterName, this.filterValueContainerTargets);

      if (valueContainer && filterName && filterType && parsedOperator) {
        const parsedValue = this.parseFilterValue(valueContainer, filterName, filterType, parsedOperator) as string[]|null;

        if (parsedValue) {
          filters.push({ name: filterName, operator: parsedOperator, value: parsedValue });
        }
      }
    });

    return filters;
  }

  private buildFilterString(filter:InternalFilterValue) {
    const valuesString = filter.value.length > 1 ? `[${filter.value.map((v) => `"${this.replaceDoubleQuotes(v)}"`).join(',')}]` : `"${this.replaceDoubleQuotes(filter.value[0])}"`;

    return `${filter.name} ${filter.operator} ${valuesString}`;
  }

  private buildFilterJSON(filter:InternalFilterValue) {
    return { [filter.name]: { operator: filter.operator, values: filter.value } };
  }

  private buildFiltersParam(filters:InternalFilterValue[]):string {
    if (this.outputFormatValue === 'json') {
      return JSON.stringify(filters.map((filter) => this.buildFilterJSON(filter)));
    }
    return filters.map((filter) => this.buildFilterString(filter)).join('&');
  }

  private replaceDoubleQuotes(value:string) {
    return value && value.length > 0 ? value.replace(/"/g, '\\"') : '';
  }

  private readonly operatorsWithoutValues = ['*', '!*', 't', 'w'];
  private readonly selectFilterTypes = ['list', 'list_all', 'list_optional'];
  private readonly dateFilterTypes = ['datetime_past', 'date'];

  private parseFilterValue(valueContainer:HTMLElement, filterName:string, filterType:string, operator:string) {
    const checkbox = valueContainer.querySelector<HTMLInputElement>('input[type="checkbox"]');

    if (checkbox) {
      return [checkbox.checked ? 't' : 'f'];
    }

    if (valueContainer.dataset.filterAutocomplete === 'true') {
      return (valueContainer.querySelector<HTMLInputElement>('input[name="value"]'))?.value.split(',');
    }

    if (this.operatorsWithoutValues.includes(operator)) {
      return [];
    }

    if (this.selectFilterTypes.includes(filterType)) {
      return this.parseSelectFilterValue(valueContainer, filterName);
    }

    if (this.dateFilterTypes.includes(filterType)) {
      return this.parseDateFilterValue(valueContainer, filterName);
    }

    const value = this.findTargetByName(filterName, this.simpleValueTargets)?.value;

    if (value && value.length > 0) {
      return [value];
    }
    return null;
  }

  private parseSelectFilterValue(valueContainer:HTMLElement, filterName:string) {
    const isMultiMode = valueContainer.dataset.multiValue === 'true';
    let selectFields;

    if (isMultiMode) {
      selectFields = this.filterValueSelectTargets.filter((selectField) => selectField.multiple && selectField.getAttribute('data-filter-name') === filterName);
    } else {
      selectFields = this.filterValueSelectTargets.filter((selectField) => !selectField.multiple && selectField.getAttribute('data-filter-name') === filterName);
    }

    const selectedValues = _.flatten(Array.from(selectFields).map((selectField) => Array.from(selectField.selectedOptions).map((option) => option.value)));

    if (selectedValues.length > 0) {
      return selectedValues;
    }

    return null;
  }

  private parseDateFilterValue(_valueContainer:HTMLElement, filterName:string) {
    let value;
    const operator = this.findTargetByName(filterName, this.operatorTargets)?.value;

    if (operator && this.daysOperators.includes(operator)) {
      const dateValue = this.findTargetByName(filterName, this.daysTargets)?.value;

      value = _.without([dateValue], '');
    } else if (operator === this.onDateOperator) {
      const dateValue = this.findTargetById(filterName, this.singleDayTargets)?.value;

      value = _.without([dateValue], '');
    } else if (operator === this.betweenDatesOperator) {
      const rangeValue = this.findTargetById(filterName, this.dateRangeTargets)?.value;
      const [fromValue, toValue] = rangeValue?.split(' - ') ?? [];

      value = [fromValue, toValue];
    }
    if (value && value.length > 0) {
      return value;
    }
    return null;
  }

  private findTargetByName<T extends HTMLElement>(
    filterName:string,
    targets:T[],
    targetFilter?:FilterFunc<T>,
  ):T | undefined {
    return this.findTargetBy(
      filterName,
      (target:T) => target.getAttribute('data-filter-name'),
      targets,
      targetFilter,
    );
  }

  private findTargetById<T extends HTMLElement>(
    filterName:string,
    targets:T[],
    targetFilter?:FilterFunc<T>,
  ):T | undefined {
    return this.findTargetBy(filterName, (target:T) => target.id, targets, targetFilter);
  }

  private findTargetBy<T extends HTMLElement>(
    attributeValue:string,
    attributeGetter:(_target:T) => string | null,
    targets:T[],
    targetFilter?:FilterFunc<T>,
  ):T | undefined {
    return targets.find((target) => {
      return attributeGetter(target) === attributeValue && (!targetFilter || targetFilter(target));
    });
  }
}
