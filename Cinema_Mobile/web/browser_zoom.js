// Let the browser handle zoom before Flutter consumes wheel/keyboard events.
window.addEventListener('wheel', (event) => {
  if (event.ctrlKey) event.stopImmediatePropagation();
}, { capture: true, passive: true });

for (const type of ['keydown', 'keyup']) {
  window.addEventListener(type, (event) => {
    if ((event.ctrlKey || event.metaKey) && ['+', '=', '-', '0'].includes(event.key)) {
      event.stopImmediatePropagation();
    }
  }, { capture: true });
}
