/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-return */

import { draggable, dropTargetForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { preventUnhandled } from '@atlaskit/pragmatic-drag-and-drop/prevent-unhandled';

import ItemController from './item.controller';

vi.mock('@atlaskit/pragmatic-drag-and-drop/combine', () => ({
  combine: vi.fn(() => vi.fn()),
}));

vi.mock('@atlaskit/pragmatic-drag-and-drop/element/adapter', () => ({
  draggable: vi.fn(() => vi.fn()),
  dropTargetForElements: vi.fn(() => vi.fn()),
}));

vi.mock('@atlaskit/pragmatic-drag-and-drop/prevent-unhandled', () => ({
  preventUnhandled: {
    start: vi.fn(),
    stop: vi.fn(),
  },
}));

describe('Backlogs item controller', () => {
  type TestItemState =
    | { type:'idle' }
    | { type:'is-dragging-over'; closestEdge:'top' | 'bottom' | null };

  interface TestItemController {
    state:TestItemState;
    setState(state:TestItemState):void;
  }

  function controllerFor(element:HTMLElement) {
    const controller = Object.create(ItemController.prototype) as unknown as TestItemController;

    Object.defineProperty(controller, 'element', { value: element });
    controller.state = { type: 'idle' };

    return controller;
  }

  function connectedControllerFor(element:HTMLElement) {
    const controller = Object.create(ItemController.prototype) as ItemController;

    Object.defineProperty(controller, 'element', { value: element });
    Object.defineProperty(controller, 'itemIdValue', { value: '123' });
    (controller as unknown as TestItemController).state = { type: 'idle' };

    controller.connect();

    return controller;
  }

  it('marks the closest edge while dragging over an item', () => {
    const element = document.createElement('article');
    const controller = controllerFor(element);

    controller.setState({ type: 'is-dragging-over', closestEdge: 'top' });

    expect(element.dataset.dropPosition).toEqual('top');
  });

  it('marks the closest edge on the containing row when present', () => {
    const row = document.createElement('li');
    const element = document.createElement('article');
    const controller = controllerFor(element);

    row.classList.add('Box-row');
    row.appendChild(element);

    controller.setState({ type: 'is-dragging-over', closestEdge: 'top' });

    expect(row.dataset.dropPosition).toEqual('top');
    expect(element.hasAttribute('data-drop-position')).toBe(false);
  });

  it('removes the drop position when leaving an item', () => {
    const row = document.createElement('li');
    const element = document.createElement('article');
    const controller = controllerFor(element);

    row.classList.add('Box-row');
    row.appendChild(element);

    controller.setState({ type: 'is-dragging-over', closestEdge: 'bottom' });
    controller.setState({ type: 'idle' });

    expect(row.hasAttribute('data-drop-position')).toBe(false);
    expect(element.hasAttribute('data-drop-position')).toBe(false);
  });

  it('keeps the item drop target active while moving through row gaps', () => {
    const element = document.createElement('article');

    connectedControllerFor(element);

    expect(vi.mocked(dropTargetForElements).mock.lastCall?.[0].getIsSticky?.({
      element,
      input: {} as never,
      source: {
        data: {},
        element: document.createElement('article'),
      } as never,
    })).toBe(true);
  });

  it('does not expose native external drag data', () => {
    const element = document.createElement('article');

    connectedControllerFor(element);

    expect(vi.mocked(draggable).mock.lastCall?.[0].getInitialDataForExternal).toBeUndefined();
  });

  it('prevents unhandled browser drag feedback while dragging an item', () => {
    const element = document.createElement('article');

    connectedControllerFor(element);

    vi.mocked(draggable).mock.lastCall?.[0].onDragStart?.({} as never);
    expect(preventUnhandled.start).toHaveBeenCalledOnce();

    vi.mocked(draggable).mock.lastCall?.[0].onDrop?.({} as never);
    expect(preventUnhandled.stop).toHaveBeenCalledOnce();
  });
});
