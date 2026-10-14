/* Operation-level API browser for the Imgproc GNATdoc index.
 * Progressive enhancement only: every entry is a native link into the
 * documentation frame and works without this script. Destinations always
 * come from the verified static entries, never from URL or search text. */
(() => {
  'use strict';
  const controls = document.getElementById('api-search-controls');
  const input = document.getElementById('api-search');
  const clear = document.getElementById('api-clear');
  const status = document.getElementById('api-results');
  const frame = document.querySelector('iframe[name="document-content"]');
  const unit = document.querySelector('#compilation-units + ul a');
  const entries = Array.from(document.querySelectorAll('#api-browser li[data-op]'));
  const categories = Array.from(document.querySelectorAll('#api-browser details'));
  if (!controls || !input || !clear || !status || !frame || !unit || !entries.length) {
    return;
  }
  controls.hidden = false;

  const show = href => frame.contentWindow.location.replace(href);

  const filter = () => {
    const words = input.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
    let shown = 0;
    for (const entry of entries) {
      const match = words.every(word => entry.dataset.search.includes(word));
      entry.hidden = !match;
      if (match) shown += 1;
    }
    for (const category of categories) {
      const visible = category.querySelector('li[data-op]:not([hidden])') !== null;
      category.hidden = !visible;
      if (words.length) category.open = visible;
    }
    status.textContent = !words.length ? ''
      : shown === 0 ? 'No matching declarations.'
      : `${shown} matching declaration${shown === 1 ? '' : 's'}.`;
  };

  const mark = entry => {
    for (const other of entries) other.firstElementChild.removeAttribute('aria-current');
    if (!entry) return;
    entry.firstElementChild.setAttribute('aria-current', 'page');
    entry.closest('details').open = true;
  };

  const bookmark = entry => {
    const url = new URL(location.href);
    url.search = '';
    url.hash = '';
    url.searchParams.set('op', entry.dataset.op);
    if (entry.dataset.overload) url.searchParams.set('overload', entry.dataset.overload);
    return url.href;
  };

  /* Case-insensitive Ada identifier lookup; unknown requests select nothing. */
  const requested = () => {
    const params = new URLSearchParams(location.search);
    const op = (params.get('op') || '').toLowerCase();
    const overload = params.get('overload') || '1';
    if (!op) return null;
    return entries.find(entry => entry.dataset.op.toLowerCase() === op &&
      (entry.dataset.overload || '1') === overload) || null;
  };

  const restore = () => {
    const entry = requested();
    mark(entry);
    show(entry ? entry.firstElementChild.href : unit.href);
    if (entry) entry.firstElementChild.scrollIntoView({block: 'nearest'});
  };

  for (const entry of entries) {
    entry.firstElementChild.addEventListener('click', event => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey ||
          event.altKey) {
        return;
      }
      event.preventDefault();
      mark(entry);
      history.pushState(null, '', bookmark(entry));
      show(entry.firstElementChild.href);
    });
  }
  input.addEventListener('input', filter);
  clear.addEventListener('click', () => {
    input.value = '';
    filter();
    input.focus();
  });
  window.addEventListener('popstate', restore);
  /* Canonicalize the outer URL: an entry's own bookmark, or no request. */
  const entry = requested();
  if (entry) {
    history.replaceState(null, '', bookmark(entry));
  } else if (location.search) {
    const url = new URL(location.href);
    url.search = '';
    history.replaceState(null, '', url.href);
  }
  restore();
  filter();
})();
